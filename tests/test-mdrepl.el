;;; tests/test-mdrepl.el --- headless tests for mdrepl.el -*- lexical-binding: t; -*-

;; Run: emacs -Q --batch -L lisp -l tests/test-mdrepl.el
;;
;; Mirrors the nvim config's tests/test_mdrepl.lua: block detection and
;; per-language numbering, command resolution for every case, code wrapping,
;; and an end-to-end send into a real `python3' REPL.

(require 'ert)
(add-to-list 'load-path (expand-file-name "lisp" (locate-dominating-file default-directory "lisp")))
(require 'mdrepl)

(defmacro mdrepl-test--with-md (text &rest body)
  "Run BODY in a temp markdown buffer containing TEXT."
  (declare (indent 1))
  `(with-temp-buffer
     (insert ,text)
     (goto-char (point-min))
     ,@body))

(defconst mdrepl-test--page "\
# Sample

Prose before.

```python
import numpy as np
x = 1
```

Some words.

```r
y <- 2
```

```python
x + 1
```

```text
not runnable
```

```julia
z = 3
```
")

(ert-deftest mdrepl-blocks-detects-and-numbers ()
  (mdrepl-test--with-md mdrepl-test--page
    (let ((blocks (mdrepl--blocks)))
      ;; python, r, python, julia — the ```text block is ignored.
      (should (equal (mapcar (lambda (b) (plist-get b :lang)) blocks)
                     '("python" "r" "python" "julia")))
      ;; per-language 1-based numbering
      (should (equal (mapcar (lambda (b) (plist-get b :n)) blocks)
                     '(1 1 2 1)))
      ;; code excludes the fences
      (should (equal (plist-get (nth 0 blocks) :code) "import numpy as np\nx = 1\n"))
      (should (equal (plist-get (nth 2 blocks) :code) "x + 1\n")))))

(ert-deftest mdrepl-locate-inside-block ()
  (mdrepl-test--with-md mdrepl-test--page
    (search-forward "x = 1")
    (pcase-let ((`(,blk . ,_) (mdrepl--locate)))
      (should blk)
      (should (equal (plist-get blk :lang) "python"))
      (should (equal (plist-get blk :n) 1))))
  (mdrepl-test--with-md mdrepl-test--page
    (search-forward "Some words")
    (should-not (car (mdrepl--locate)))))

(ert-deftest mdrepl-locate-on-fence ()
  (mdrepl-test--with-md mdrepl-test--page
    (search-forward "```r")
    (beginning-of-line)
    (pcase-let ((`(,blk . ,_) (mdrepl--locate)))
      (should blk)
      (should (equal (plist-get blk :lang) "r")))))

(ert-deftest mdrepl-upto ()
  (mdrepl-test--with-md mdrepl-test--page
    (search-forward "Some words")
    ;; between python block 1 and the r block: last python above is #1
    (pcase-let ((`(,lang ,n ,_) (mdrepl--upto)))
      (should (equal lang "python"))
      (should (equal n 1))))
  (mdrepl-test--with-md mdrepl-test--page
    (goto-char (point-min))
    (pcase-let ((`(,lang ,n ,_) (mdrepl--upto)))
      (should (equal lang "python"))
      (should (equal n 0)))))

(ert-deftest mdrepl-wrap-bracketed ()
  (let ((mdrepl-bracketed-paste t))
    (should (equal (mdrepl--wrap "a\nb\n\n") "\e[200~a\nb\e[201~\r"))
    (should-not (mdrepl--wrap "\n\n"))
    (should-not (mdrepl--wrap ""))))

(ert-deftest mdrepl-wrap-linewise ()
  (let ((mdrepl-bracketed-paste nil))
    ;; interior blank lines dropped; trailing blank line to execute
    (should (equal (mdrepl--wrap "def f():\n\n    return 1\n") "def f():\n    return 1\n\n"))))

(ert-deftest mdrepl-resolve-override ()
  (with-temp-buffer
    (setq-local mdrepl-cmd '("python3" "-m" "IPython"))
    (let ((res (mdrepl--resolve "python")))
      (should (equal (plist-get res :cmd) '("python3" "-m" "IPython")))
      (should (string-prefix-p "override::" (plist-get res :key))))))

(ert-deftest mdrepl-resolve-fallback ()
  ;; A buffer in a directory with no project markers.
  (let ((default-directory temporary-file-directory))
    (with-temp-buffer
      (setq buffer-file-name (expand-file-name "scratch-nowhere.md" temporary-file-directory))
      (let ((py (mdrepl--resolve "python"))
            (jl (mdrepl--resolve "julia")))
        (should (equal (plist-get py :cmd) '("python3")))
        (should (equal (plist-get jl :cmd) '("julia")))))))

(ert-deftest mdrepl-resolve-ideeep ()
  (let ((page (getenv "MDREPL_TEST_IDEEEP_PAGE")))
    (skip-unless (and page (file-exists-p page)))
    (with-temp-buffer
      (setq buffer-file-name (expand-file-name page))
      (setq default-directory (file-name-directory buffer-file-name))
      (let ((py (mdrepl--resolve "python"))
            (rr (mdrepl--resolve "r")))
        (should (plist-get py :ideeep))
        (should (member "--none" (plist-get py :cmd)))
        (should (member "repl_blocks.py" (mapcar #'file-name-nondirectory (plist-get py :cmd))))
        ;; R adds --lang r; python does not
        (should (member "--lang" (plist-get rr :cmd)))
        (should (member "r" (plist-get rr :cmd)))
        (should-not (member "--lang" (plist-get py :cmd)))
        ;; per-page-per-language keys differ
        (should-not (equal (plist-get py :key) (plist-get rr :key)))))))

(ert-deftest mdrepl-end-to-end-python ()
  (skip-unless (executable-find "python3"))
  (let ((default-directory temporary-file-directory)
        (mdrepl-bracketed-paste nil))
    (with-temp-buffer
      (setq buffer-file-name (expand-file-name "e2e.md" temporary-file-directory))
      (setq-local mdrepl-cmd '("python3" "-u"))
      (let* ((res (mdrepl--resolve "python"))
             (st (mdrepl--ensure res))
             (deadline (+ (float-time) 20)))
        (unwind-protect
            (progn
              ;; wait for the >>> prompt
              (while (and (not (mdrepl--repl-ready st)) (< (float-time) deadline))
                (accept-process-output (mdrepl--repl-process st) 0.2))
              (should (mdrepl--repl-ready st))
              (mdrepl--send res "print(6 * 7)")
              (let ((seen nil))
                (setq deadline (+ (float-time) 15))
                (while (and (not seen) (< (float-time) deadline))
                  (accept-process-output (mdrepl--repl-process st) 0.2)
                  (with-current-buffer (mdrepl--repl-buffer st)
                    (when (save-excursion
                            (goto-char (point-min))
                            (re-search-forward "^42$" nil t))
                      (setq seen t))))
                (should seen)))
          (mdrepl--cleanup (plist-get res :key)))))))

(let ((ert-batch-backtrace-right-margin 200))
  (ert-run-tests-batch-and-exit))
;;; test-mdrepl.el ends here
