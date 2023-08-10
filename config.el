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
      user-mail-address "medewitt@wakehealth.edu")

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

;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
