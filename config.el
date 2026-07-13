;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-unicode-font' -- for unicode glyphs
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

(setq user-full-name "Michael DeWitt"
      user-mail-address "michael.dewitt@wfusm.edu")

(setq projectile-project-search-path '("~/projects/" "~/wfu-id/" "~/Library/CloudStorage/Box-Box/"))
(setq projectile-indexing-method 'alien) ; Or 'turbo-alien

;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.

(custom-set-faces!
  '(aw-leading-char-face
    :foreground "white" :background "red"
    :weight bold :height 2.5 :box (:line-width 10 :color "red"))
  )

(global-set-key (kbd "<mouse-3>") 'clipboard-yank)

;; ESS from https://github.com/kjhealy/.doom.d/blob/main/config.el
;;
(use-package! ess-mode

  :config
  (add-hook! 'ess-mode-hook
    (setq! ess-use-flymake nil
           lsp-ui-doc-enable nil
           lsp-ui-doc-delay 1.5
           polymode-lsp-integration nil
           ess-style 'RStudio
           ess-offset-continued 2
           ess-expression-offset 0
           comint-scroll-to-bottom-on-output t)

  (setq! ess-R-font-lock-keywords
        '((ess-R-fl-keyword:modifiers  . t)
          (ess-R-fl-keyword:fun-defs   . t)
          (ess-R-fl-keyword:keywords   . t)
          (ess-R-fl-keyword:assign-ops . t)
          (ess-R-fl-keyword:constants  . t)
          (ess-fl-keyword:fun-calls    . t)
          (ess-fl-keyword:numbers      . t)
          (ess-fl-keyword:operators    . t)
          (ess-fl-keyword:delimiters) ; don't because of rainbow delimiters
          (ess-fl-keyword:=            . t)
          (ess-R-fl-keyword:F&T        . t)
          (ess-R-fl-keyword:%op%       . t)))
  )

  ;; ESS buffers should not be cleaned up automatically
  (add-hook 'inferior-ess-mode-hook #'doom-mark-buffer-as-real-h)

  ;; Assignment
  (define-key ess-mode-map "_" #'ess-insert-assign)
  (define-key inferior-ess-mode-map "_" #'ess-insert-assign)

  (defun kjh/then-R-operator ()
    "R - %>% operator or 'then' pipe operator"
    (interactive)
    (just-one-space 1)
    (insert "|>")
    (reindent-then-newline-and-indent))
  (define-key ess-mode-map (kbd "C-|") 'kjh/then_R_operator)
  (define-key inferior-ess-mode-map (kbd "C-|") 'kjh/then-R-operator)

  ;; mirror R-Studio's cmd-shift-M binding for %>%
  (map! "s-M" #'kjh/then-R-operator)

)


;; polymode
(use-package! poly-R
  :config
    (defun kjh/insert-r-chunk (header)
  "Insert an r-chunk in markdown mode."
  (interactive "sLabel: ")
  (insert (concat "```{r " header "}\n\n```"))
  (forward-line -1))

  ;; (add-to-list 'auto-mode-alist '("\\.Rmarkdown" . poly-markdown+r-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.Rmd" . poly-markdown+r-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.qmd" . poly-markdown+r-mode))
  (map! (:localleader
         :map polymode-mode-map
         :desc "Export"   "e" 'polymode-export
         :desc "Errors" "$" 'polymode-show-process-buffer
         :desc "Eval region or chunk" "v" 'polymode-eval-region-or-chunk
         :desc "Eval from top" "v" 'polymode-eval-buffer-from-beg-to-point
         :desc "Weave" "w" 'polymode-weave
         :desc "New chunk" "c" 'kjh/insert-r-chunk
         :desc "Next" "n" 'polymode-next-chunk
         :desc "Previous" "p" 'polymode-previous-chunk
         ;; (:prefix ("c" . "Chunks")
         ;;   :desc "Narrow" "n" . 'polymode-toggle-chunk-narrowing
         ;;   :desc "Kill" "k" . 'polymode-kill-chunk
         ;;   :desc "Mark-Extend" "m" . 'polymode-mark-or-extend-chunk)
         ))
)

;; mdrepl — send markdown ```python / ```r / ```julia blocks to a live REPL,
;; Quarto/RMarkdown-chunk style. Emacs port of the nvim config's lua/mdrepl.lua
;; (medewitt/nvim), tuned for the ideeep content pages: on a page it launches
;; `uv run --script scripts/repl_blocks.py <page> [--lang r|julia] --none`, the
;; same environment the site's output injector uses. Elsewhere it falls back to
;; python3 / radian-or-R / julia.
(add-load-path! "lisp")
(use-package! mdrepl
  :commands (mdrepl-send-dwim mdrepl-send-block mdrepl-send-region
             mdrepl-run-above mdrepl-preload mdrepl-toggle mdrepl-kill)
  :init
  ;; The repl menu must be reachable from every mode a code block can live in.
  ;; With polymode active (the ideeep pages show `foo.md[python]' in the
  ;; modeline), point inside a ```python fence puts the buffer in
  ;; `python-mode', so bindings only on the markdown maps are shadowed there
  ;; and `SPC m r' reports "undefined".  Bind the markdown host maps, the inner
  ;; `python-mode-map', and the polymode minor-mode map.
  (map! :after markdown-mode
        :map (markdown-mode-map gfm-mode-map)
        :localleader
        (:prefix ("r" . "repl")
         :desc "Send block/region"        "r" #'mdrepl-send-dwim
         :desc "Send block"               "RET" #'mdrepl-send-block
         :desc "Run blocks 1..point"      "a" #'mdrepl-run-above
         :desc "Fresh REPL w/ page state" "A" #'mdrepl-preload
         :desc "Toggle REPL window"       "o" #'mdrepl-toggle
         :desc "Quit REPL"                "q" #'mdrepl-kill)
        :nv "<leader><return>" #'mdrepl-send-dwim)
  (map! :after python
        :map python-mode-map
        :localleader
        (:prefix ("r" . "repl")
         :desc "Send block/region"        "r" #'mdrepl-send-dwim
         :desc "Send block"               "RET" #'mdrepl-send-block
         :desc "Run blocks 1..point"      "a" #'mdrepl-run-above
         :desc "Fresh REPL w/ page state" "A" #'mdrepl-preload
         :desc "Toggle REPL window"       "o" #'mdrepl-toggle
         :desc "Quit REPL"                "q" #'mdrepl-kill)
        :nv "<leader><return>" #'mdrepl-send-dwim)
  (map! :after polymode
        :map polymode-mode-map
        :localleader
        (:prefix ("r" . "repl")
         :desc "Send block/region"        "r" #'mdrepl-send-dwim
         :desc "Send block"               "RET" #'mdrepl-send-block
         :desc "Run blocks 1..point"      "a" #'mdrepl-run-above
         :desc "Fresh REPL w/ page state" "A" #'mdrepl-preload
         :desc "Toggle REPL window"       "o" #'mdrepl-toggle
         :desc "Quit REPL"                "q" #'mdrepl-kill)
        :nv "<leader><return>" #'mdrepl-send-dwim))

;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;; treemacs-evil and treemacs-projectile are already provided by Doom's
;; `:ui treemacs' module, so no extra `use-package!' is needed.

;; On macOS, pull PATH/env from the login shell so GUI Emacs sees the same
;; tools (R, julia, uv, etc.) as the terminal.
(use-package! exec-path-from-shell
  :when (memq window-system '(mac ns x))
  :config
  (exec-path-from-shell-initialize))

;; ESS: execute region/paragraph, save the plot to a temp PDF, and open it in a
;; side window. Adapted from the rutils snippet; keybinding lives in an
;; `after! ess' so `ess-mode-map' exists when it is bound.
(defvar rutils-show-plot-next-to-r-process t)

(defun add-pdf-to-rcode (rcomm fname)
  "Wrap RCOMM so its plot output is written to FNAME as a PDF."
  (concat "pdf('" fname "')\n" rcomm "\n dev.off()"))

(defun rutils-plot-region-or-paragraph ()
  "Run region or paragraph, save its plot to a temp PDF, and show it."
  (interactive)
  (let ((fname (concat (make-temp-file "plot_") ".pdf")))
    (if (use-region-p)
        (ess-eval-linewise
         (add-pdf-to-rcode
          (buffer-substring (region-beginning) (region-end)) fname))
      (ess-eval-linewise
       (add-pdf-to-rcode (thing-at-point 'paragraph) fname)))
    (when rutils-show-plot-next-to-r-process
      (ess-switch-to-end-of-ESS))
    (if (window-in-direction 'right)
        (select-window (window-in-direction 'right))
      (progn
        (split-window-right)
        (select-window (window-in-direction 'right))))
    (find-file fname)))

(after! ess
  (define-key ess-mode-map (kbd "C-c g") #'rutils-plot-region-or-paragraph))

;; Python: no anaconda-mode (its bundled jedi crashes on Python 3.14, and we
;; want to stay off the anaconda/conda stack entirely — see packages.el where
;; anaconda-mode and company-anaconda are disabled).  Prefer the Homebrew
;; python3 for `run-python', never the macOS /usr/bin one; project
;; environments are handled by uv (and by mdrepl for markdown code blocks).
(after! python
  (setq python-shell-interpreter
        (cond ((file-executable-p "/opt/homebrew/bin/python3")
               "/opt/homebrew/bin/python3")
              ((file-executable-p "/usr/local/bin/python3")
               "/usr/local/bin/python3")
              (t "python3"))))
