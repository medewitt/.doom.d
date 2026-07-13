;;; lisp/mdrepl.el --- send markdown code blocks to a live REPL -*- lexical-binding: t; -*-

;; Emacs port of the nvim config's lua/mdrepl.lua (medewitt/nvim).
;;
;; Quarto/RMarkdown-style chunk execution for plain markdown: put point in a
;; ```python / ```r / ```julia fenced block and send it to that language's
;; own persistent REPL in a terminal split below.  Each language gets its own
;; REPL, resolved per buffer (override variable > ideeep-style repl_blocks.py
;; > uv project > plain interpreter), and it stays alive until the process
;; exits.  Sends are queued until the REPL prints its first prompt, so a cold
;; multi-minute `uv run' dependency resolve loses nothing.
;;
;; On ideeep content pages the REPL command is
;;   uv run --script scripts/repl_blocks.py <page> [--lang r|julia] --none
;; run from the project root — an IPython/R/julia prompt in the same
;; environment the site's output injector uses, one REPL per page per
;; language.
;;
;; Built on vterm (emacs-libvterm) — the same libvterm terminal nvim's
;; `:terminal' uses — so IPython/prompt_toolkit render correctly and bracketed
;; paste round-trips cleanly (term.el garbles both).  vterm is required lazily
;; the first time a REPL starts.  Keybindings live in config.el (markdown
;; localleader).

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defgroup mdrepl nil
  "Send markdown fenced code blocks to a persistent REPL."
  :group 'tools)

(defcustom mdrepl-height 12
  "Height of the REPL window, in lines."
  :type 'integer)

(defcustom mdrepl-ready-timeout 180
  "Seconds to wait before warning that the REPL still shows no prompt."
  :type 'number)

(defcustom mdrepl-advance t
  "Whether `mdrepl-send-block' moves point to the next same-language block."
  :type 'boolean)

(defcustom mdrepl-bracketed-paste t
  "Send code as a bracketed paste (one unit).
IPython (what ideeep's repl_blocks.py opens), Python >= 3.13, radian,
R (readline >= 8.1) and julia all support it.  Set to nil for classic
line-based REPLs (old python's >>>, code.interact): interior blank lines
are stripped instead, and a final blank line executes the rest."
  :type 'boolean)

(defvar mdrepl-cmd nil
  "Override for the python REPL command: a list of strings, or a shell string.
May be set buffer-locally.  When nil the command is resolved from the
project (see `mdrepl--resolve').")

(defvar mdrepl-cmd-r nil
  "Override for the R REPL command; see `mdrepl-cmd'.")

(defvar mdrepl-cmd-julia nil
  "Override for the julia REPL command; see `mdrepl-cmd'.")

;; Languages recognized as runnable fences.  :override names the variable
;; consulted first; :fallback is the command used outside any project.
(defconst mdrepl--langs
  `(("python" :override mdrepl-cmd
     :fallback ,(lambda () '("python3")))
    ("r" :override mdrepl-cmd-r
     :fallback ,(lambda ()
                  (if (executable-find "radian")
                      '("radian")
                    '("R" "--no-save" "--quiet"))))
    ("julia" :override mdrepl-cmd-julia
     :fallback ,(lambda () '("julia")))))

;; One live REPL per key (the key encodes project root + page + language).
(defvar mdrepl--repls (make-hash-table :test #'equal))

(cl-defstruct mdrepl--repl buffer process ready queue timer poll)

;; ---------------------------------------------------------------------------
;; REPL command resolution

(defun mdrepl--resolve (lang)
  "Resolve the REPL command for LANG in the current buffer.
Return a plist (:cmd LIST :cwd DIR :key STRING), plus :ideeep t and
:page PAGE for ideeep-style projects.  First match wins: the language's
override variable, a scripts/repl_blocks.py found upward from the file,
a pyproject.toml/uv.lock (python only), then the plain interpreter."
  (let* ((spec (cdr (assoc lang mdrepl--langs)))
         (file (expand-file-name
                (or (buffer-file-name (buffer-base-buffer))
                    (expand-file-name "unnamed.md" default-directory))))
         (dir (file-name-directory file))
         (override (symbol-value (plist-get spec :override))))
    (cond
     (override
      (list :cmd (if (stringp override)
                     (list shell-file-name shell-command-switch override)
                   override)
            :cwd dir
            :key (concat "override::"
                         (if (stringp override)
                             override
                           (string-join override " ")))))
     ;; ideeep-style project: repl_blocks.py opens a REPL in the page's
     ;; environment (uv-managed PEP 723 deps + IPython for python; R and
     ;; julia sessions with page-state support via --lang/--through).
     ((when-let* ((root (locate-dominating-file dir "scripts/repl_blocks.py")))
        (let* ((root (expand-file-name root))
               (script (expand-file-name "scripts/repl_blocks.py" root))
               (page (file-relative-name file root)))
          (list :cmd (append (list "uv" "run" "--script" script page)
                             (unless (equal lang "python")
                               (list "--lang" lang))
                             (list "--none"))
                :cwd root
                :key (format "%s::%s::%s" root page lang) ; per page and language
                :ideeep t :page page))))
     ((and (equal lang "python")
           (when-let* ((root (or (locate-dominating-file dir "pyproject.toml")
                                 (locate-dominating-file dir "uv.lock"))))
             (list :cmd '("uv" "run" "python")
                   :cwd (expand-file-name root)
                   :key (format "%s::%s" (expand-file-name root) lang)))))
     (t
      (list :cmd (funcall (plist-get spec :fallback))
            :cwd dir
            :key (format "%s::%s" dir lang))))))

;; ---------------------------------------------------------------------------
;; Code-block detection

(defun mdrepl--blocks ()
  "Runnable fenced blocks of the current buffer, in document order.
Each element is a plist (:beg :end :cbeg :code :lang :n): :beg/:end are the
1-based line numbers of the opening/closing fences (inclusive), :cbeg the
first content line, and :n the block's 1-based index within its language —
matching repl_blocks.py's --block/--through numbering."
  (save-excursion
    (save-restriction
      (widen)
      (goto-char (point-min))
      (let (blocks counts)
        (while (re-search-forward "^```[ \t]*\\([A-Za-z0-9_]+\\)[ \t]*$" nil t)
          (let ((lang (downcase (match-string-no-properties 1)))
                (beg (line-number-at-pos))
                (content-start (1+ (line-end-position))))
            (when (and (assoc lang mdrepl--langs)
                       (re-search-forward "^```[ \t]*$" nil t))
              (let* ((end (line-number-at-pos))
                     (n (1+ (or (cdr (assoc lang counts)) 0)))
                     (code (buffer-substring-no-properties
                            (min content-start (line-beginning-position))
                            (line-beginning-position))))
                (setf (alist-get lang counts nil nil #'equal) n)
                (push (list :beg beg :end end :cbeg (1+ beg)
                            :code code :lang lang :n n)
                      blocks)))))
        (nreverse blocks)))))

(defun mdrepl--locate ()
  "Return (BLOCK . BLOCKS): the block containing point (fences count), or nil."
  (let ((line (line-number-at-pos))
        (blocks (mdrepl--blocks)))
    (cons (cl-find-if (lambda (b) (and (<= (plist-get b :beg) line)
                                       (<= line (plist-get b :end))))
                      blocks)
          blocks)))

(defun mdrepl--upto ()
  "Return (LANG N BLOCKS) at point.
The containing block's language and per-language index, or the last python
block that ends above point (N = 0 when there is none)."
  (pcase-let ((`(,blk . ,blocks) (mdrepl--locate)))
    (if blk
        (list (plist-get blk :lang) (plist-get blk :n) blocks)
      (let ((line (line-number-at-pos)) (n 0))
        (dolist (b blocks)
          (when (and (equal (plist-get b :lang) "python")
                     (< (plist-get b :end) line))
            (setq n (plist-get b :n))))
        (list "python" n blocks)))))

;; ---------------------------------------------------------------------------
;; Terminal / process management (vterm backend)

(declare-function vterm-mode "ext:vterm")
(defvar vterm-shell)
(defvar vterm-kill-buffer-on-exit)
(defvar vterm-exit-functions)

(defun mdrepl--display (buf)
  "Show BUF in a fixed-height window at the bottom; return the window."
  (let ((win (or (get-buffer-window buf)
                 (display-buffer
                  buf `((display-buffer-at-bottom)
                        (window-height . ,mdrepl-height)
                        (preserve-size . (nil . t)))))))
    (when win (set-window-dedicated-p win t))
    win))

(defun mdrepl--forget (key &optional kill)
  "Drop KEY's REPL state and cancel its timers.
With KILL non-nil also kill the REPL process and buffer; otherwise the
buffer is left in place so its output (or a startup error) stays readable."
  (when-let* ((st (gethash key mdrepl--repls)))
    (remhash key mdrepl--repls)
    (dolist (tm (list (mdrepl--repl-timer st) (mdrepl--repl-poll st)))
      (when (timerp tm) (cancel-timer tm)))
    (when kill
      (let ((buf (mdrepl--repl-buffer st)))
        (when (buffer-live-p buf)
          (when-let* ((proc (get-buffer-process buf)))
            (set-process-query-on-exit-flag proc nil)
            (delete-process proc))
          (kill-buffer buf))))))

(defun mdrepl--cleanup (key)
  "Forget the REPL for KEY, killing its process and buffer (window follows)."
  (mdrepl--forget key t))

(defun mdrepl--on-vterm-exit (buf &optional _event)
  "Forget the REPL whose vterm BUF exited, leaving the buffer visible."
  (when (bufferp buf)
    (let (key)
      (maphash (lambda (k st)
                 (when (eq (mdrepl--repl-buffer st) buf) (setq key k)))
               mdrepl--repls)
      (when key (mdrepl--forget key nil)))))

(with-eval-after-load 'vterm
  (add-hook 'vterm-exit-functions #'mdrepl--on-vterm-exit))

;; The REPL is "ready" once it shows a prompt; until then sends are queued.
;; IPython "In [", python ">>>", the repl_blocks banner "[repl]", radian
;; "r$>", R / julia "> " / "julia>".
(defconst mdrepl--ready-regexps
  '("In \\[" ">>>" "\\[repl\\]" "r\\$>" "julia>" "^> "))

(defun mdrepl--ready-p (buf)
  "Non-nil when the tail of vterm BUF shows a REPL prompt."
  (and (buffer-live-p buf)
       (with-current-buffer buf
         (let* ((end (point-max))
                (start (max (point-min) (- end 400)))
                (tail (buffer-substring-no-properties start end)))
           (cl-some (lambda (re) (string-match-p re tail))
                    mdrepl--ready-regexps)))))

(defun mdrepl--poll-ready (key)
  "Flush KEY's queued sends once its REPL shows a prompt.
Runs on a repeating timer because vterm owns the process filter; the timer
cancels itself once the prompt appears."
  (when-let* ((st (gethash key mdrepl--repls)))
    (cond
     ((not (buffer-live-p (mdrepl--repl-buffer st)))
      (mdrepl--forget key nil))
     ((mdrepl--repl-ready st)
      (when (timerp (mdrepl--repl-poll st))
        (cancel-timer (mdrepl--repl-poll st))))
     ((mdrepl--ready-p (mdrepl--repl-buffer st))
      (setf (mdrepl--repl-ready st) t)
      (when (timerp (mdrepl--repl-poll st))
        (cancel-timer (mdrepl--repl-poll st)))
      (setf (mdrepl--repl-poll st) nil)
      (mdrepl--flush st)))))

(defun mdrepl--warn-slow (key)
  (when-let* ((st (gethash key mdrepl--repls)))
    (when (and (not (mdrepl--repl-ready st)) (mdrepl--repl-queue st))
      (message "mdrepl: REPL still starting (a cold uv run can take a while); %d send(s) queued"
               (length (mdrepl--repl-queue st))))))

(defun mdrepl--ensure (res)
  "Return a live vterm REPL for the resolution RES, starting one if needed."
  (unless (require 'vterm nil t)
    (user-error "mdrepl: vterm is unavailable; run `M-x vterm' once to build its module"))
  (let* ((key (plist-get res :key))
         (st (gethash key mdrepl--repls)))
    (if (and st (buffer-live-p (mdrepl--repl-buffer st))
             (process-live-p (mdrepl--repl-process st)))
        (progn (mdrepl--display (mdrepl--repl-buffer st)) st)
      (when st (mdrepl--cleanup key))
      (let* ((cmd (plist-get res :cmd))
             (default-directory (file-name-as-directory (plist-get res :cwd)))
             ;; vterm runs `/bin/sh -c VTERM-SHELL', so quote each argument.
             (vterm-shell (mapconcat #'shell-quote-argument cmd " "))
             (buf (generate-new-buffer (format "*mdrepl %s*" key))))
        ;; Display before `vterm-mode' so the pty is sized to a real window.
        (mdrepl--display buf)
        (with-current-buffer buf
          (condition-case err
              (vterm-mode)
            (error (kill-buffer buf)
                   (user-error "mdrepl: could not start REPL: %s (%s)"
                               vterm-shell (error-message-string err))))
          ;; `vterm-kill-buffer-on-exit' is consulted when the process EXITS,
          ;; so a dynamic let-binding around `vterm-mode' has already unwound
          ;; by then.  Set it buffer-locally so a failed/short-lived REPL (a
          ;; broken `uv run', a crash) leaves its output on screen to read.
          (setq-local vterm-kill-buffer-on-exit nil))
        (let ((proc (get-buffer-process buf)))
          (unless (process-live-p proc)
            (kill-buffer buf)
            (user-error "mdrepl: could not start REPL: %s" vterm-shell))
          (set-process-query-on-exit-flag proc nil)
          (setq st (make-mdrepl--repl
                    :buffer buf :process proc :ready nil :queue nil
                    :timer (run-at-time mdrepl-ready-timeout nil
                                        #'mdrepl--warn-slow key)
                    :poll (run-at-time 0.5 0.5 #'mdrepl--poll-ready key)))
          (puthash key st mdrepl--repls)
          st)))))

;; ---------------------------------------------------------------------------
;; Sending

(defun mdrepl--prepare (code)
  "Return CODE trimmed for sending, or nil when it is empty.
With `mdrepl-bracketed-paste' the block is kept verbatim.  Otherwise
interior blank lines are dropped, since they terminate an indented suite
in line-based REPLs."
  (let ((code (string-trim-right (or code "") "[\n]+")))
    (unless (string-empty-p code)
      (if mdrepl-bracketed-paste
          code
        (string-join
         (seq-filter (lambda (l) (string-match-p "[^ \t]" l))
                     (split-string code "\n"))
         "\n")))))

(defun mdrepl--wire (code)
  "Turn prepared CODE into the byte string handed to the REPL process."
  (if mdrepl-bracketed-paste
      ;; Real bracketed paste (exactly what nvim's plugin sends over the pty):
      ;; IPython/python>=3.13/radian/R/julia run it as one unit and skip the
      ;; auto-indent that mangles a pasted suite.
      (concat "\e[200~" code "\e[201~\r")
    ;; Line-based REPLs: a trailing blank line closes an indented suite.
    (concat code "\n\n")))

(defun mdrepl--deliver (st code)
  "Send prepared CODE straight to ST's REPL process and execute it.
vterm is used only to render the pty; input goes to the process directly so
the bracketed-paste markers reach the REPL unconditionally."
  (let ((proc (mdrepl--repl-process st)))
    (when (process-live-p proc)
      (process-send-string proc (mdrepl--wire code)))))

(defun mdrepl--flush (st)
  "Deliver ST's queued blocks in submission order."
  (dolist (code (nreverse (mdrepl--repl-queue st)))
    (mdrepl--deliver st code))
  (setf (mdrepl--repl-queue st) nil))

(defun mdrepl--send (res code)
  "Send CODE to the REPL for RES, queueing until its prompt appears."
  (when-let* ((code (mdrepl--prepare code))
              (st (mdrepl--ensure res)))
    (if (mdrepl--repl-ready st)
        (mdrepl--deliver st code)
      (push code (mdrepl--repl-queue st)))))

;; ---------------------------------------------------------------------------
;; Commands

;;;###autoload
(defun mdrepl-send-block ()
  "Send the fenced code block at point to its language's REPL.
Point then advances to the next block of the same language, so a page can
be walked top-to-bottom by repeating the command (see `mdrepl-advance')."
  (interactive)
  (pcase-let ((`(,blk . ,blocks) (mdrepl--locate)))
    (unless blk
      (user-error "mdrepl: point is not inside a ```python / ```r / ```julia block"))
    (mdrepl--send (mdrepl--resolve (plist-get blk :lang)) (plist-get blk :code))
    (when mdrepl-advance
      (when-let* ((next (cl-find-if
                         (lambda (b)
                           (and (equal (plist-get b :lang) (plist-get blk :lang))
                                (> (plist-get b :beg) (plist-get blk :beg))))
                         blocks)))
        (goto-char (point-min))
        (forward-line (1- (plist-get next :cbeg)))))))

;;;###autoload
(defun mdrepl-send-region (beg end)
  "Send the region to the REPL of the block at point (python in prose)."
  (interactive "r")
  (pcase-let ((`(,blk . ,_) (mdrepl--locate)))
    (let ((code (buffer-substring-no-properties beg end)))
      (deactivate-mark)
      (mdrepl--send (mdrepl--resolve (if blk (plist-get blk :lang) "python"))
                    code))))

;;;###autoload
(defun mdrepl-send-dwim ()
  "Send the active region, else the fenced code block at point."
  (interactive)
  (if (use-region-p)
      (mdrepl-send-region (region-beginning) (region-end))
    (mdrepl-send-block)))

;;;###autoload
(defun mdrepl-run-above ()
  "Send same-language blocks 1..current through the live REPL."
  (interactive)
  (pcase-let ((`(,lang ,n ,blocks) (mdrepl--upto)))
    (when (zerop n)
      (user-error "mdrepl: no %s blocks at or above point" lang))
    (let ((res (mdrepl--resolve lang)))
      (dolist (b blocks)
        (when (and (equal (plist-get b :lang) lang)
                   (<= (plist-get b :n) n))
          (mdrepl--send res (plist-get b :code)))))))

;;;###autoload
(defun mdrepl-preload ()
  "Fresh REPL preloaded with page state.
Kills the current REPL; on ideeep pages it restarts with `--through N' so
repl_blocks.py executes blocks 1..N before the prompt opens (a clean
namespace that matches the page exactly), elsewhere it restarts empty and
replays blocks 1..N."
  (interactive)
  (pcase-let ((`(,lang ,n ,blocks) (mdrepl--upto)))
    (let ((res (mdrepl--resolve lang)))
      (mdrepl-kill)
      (if (and (plist-get res :ideeep) (> n 0))
          (let* ((cmd (plist-get res :cmd))
                 (pos (cl-position "--none" cmd :test #'equal))
                 (through (append (cl-subseq cmd 0 pos)
                                  (list "--through" (number-to-string n))
                                  (cl-subseq cmd (1+ pos)))))
            (mdrepl--ensure (plist-put (copy-sequence res) :cmd through)))
        (mdrepl--ensure res)
        (dolist (b blocks)
          (when (and (equal (plist-get b :lang) lang)
                     (<= (plist-get b :n) n))
            (mdrepl--send res (plist-get b :code))))))))

;;;###autoload
(defun mdrepl-toggle ()
  "Hide/show the REPL window for the language at point (the REPL keeps running).
Starts a REPL when there is none."
  (interactive)
  (pcase-let* ((`(,blk . ,_) (mdrepl--locate))
               (res (mdrepl--resolve (if blk (plist-get blk :lang) "python")))
               (st (gethash (plist-get res :key) mdrepl--repls)))
    (if (and st (process-live-p (mdrepl--repl-process st)))
        (if-let* ((win (get-buffer-window (mdrepl--repl-buffer st))))
            (delete-window win)
          (mdrepl--display (mdrepl--repl-buffer st)))
      (mdrepl--ensure res))))

;;;###autoload
(defun mdrepl-kill ()
  "Kill the REPL for the language at point and close its window."
  (interactive)
  (pcase-let ((`(,blk . ,_) (mdrepl--locate)))
    (mdrepl--cleanup
     (plist-get (mdrepl--resolve (if blk (plist-get blk :lang) "python"))
                :key))))

(provide 'mdrepl)
;;; mdrepl.el ends here
