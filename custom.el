(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(pdf-tools exec-path-from-shell company-auctex poly-R quarto-mode projectile @ stan-snippets flycheck-stan eldoc-stan company-stan stan-mode)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(aw-leading-char-face ((t (:foreground "white" :background "red" :weight bold :height 2.5 :box (:line-width 10 :color "red"))))))

(setq org-agenda-files (list "~/michael.org"))

;; Make *scratch* buffer blank.
(setq initial-scratch-message nil)


(defvar rutils-show_plot_next_to_r_process t)

(defun add-pdf-to-rcode(rcomm fname)
  "add pdf(tmpfile) and dev.off() to R command"
  (let*  (
	  (newc (concat "pdf('" fname "')\n" rcomm  "\n dev.off()"))
	  )
    (eval newc)
      )
  )


(defun rutils-plot-region-or-paragraph()
  "execute region or paragraph and save tmp plot to pdf. Then open windows to show pdf"
  (interactive)
    (let*  (
	  (fname (concat (make-temp-file "plot_") ".pdf"))
	  )
      (progn
	(if (use-region-p)
	    (ess-eval-linewise (add-pdf-to-rcode (buffer-substring (region-beginning) (region-end)) fname))
	  (progn (ess-eval-linewise (add-pdf-to-rcode (thing-at-point 'paragraph) fname)))
	  )
 	;; (with-help-window "*plots*"
	;;   (find-ssfile-at-point)
	;;   )
	(if rutils-show_plot_next_to_r_process
	    (ess-switch-to-end-of-ESS)
	    )
	(if (window-in-direction 'right)
	    (progn
	      (select-window (window-in-direction 'right))
	      (find-file fname)
	      )
	  (progn
	    (split-window-right)
	    (select-window (window-in-direction 'right))
	    (find-file fname)
	    )
	    )
	;;(split-window-right)
	;;(windmove-right)
	)
    )
    )
(define-key ess-mode-map (kbd "C-c g") 'rutils-plot-region-or-paragraph)
