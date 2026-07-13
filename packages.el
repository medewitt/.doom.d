;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; To install a package with Doom you must declare them here and run 'doom sync'
;; on the command line, then restart Emacs for the changes to take effect -- or
;; use 'M-x doom/reload'.


;; To install SOME-PACKAGE from MELPA, ELPA or emacsmirror:
;(package! some-package)

;; To install a package directly from a remote git repo, you must specify a
;; `:recipe'. You'll find documentation on what `:recipe' accepts here:
;; https://github.com/radian-software/straight.el#the-recipe-format
;(package! another-package
;  :recipe (:host github :repo "username/repo"))

;; If the package you are trying to install does not contain a PACKAGENAME.el
;; file, or is located in a subdirectory of the repo, you'll need to specify
;; `:files' in the `:recipe':
;(package! this-package
;  :recipe (:host github :repo "username/repo"
;           :files ("some-file.el" "src/lisp/*.el")))

;; If you'd like to disable a package included with Doom, you can do so here
;; with the `:disable' property:
;(package! builtin-package :disable t)

;; You can override the recipe of a built in package without having to specify
;; all the properties for `:recipe'. These will inherit the rest of its recipe
;; from Doom or MELPA/ELPA/Emacsmirror:
;(package! builtin-package :recipe (:nonrecursive t))
;(package! builtin-package-2 :recipe (:repo "myfork/package"))

;; Specify a `:branch' to install a package from a particular branch or tag.
;; This is required for some packages whose default branch isn't 'master' (which
;; our package manager can't deal with; see radian-software/straight.el#279)
;(package! builtin-package :recipe (:branch "develop"))

;; Use `:pin' to specify a particular commit to install.
;(package! builtin-package :pin "1a2b3c4d5e")


;; Doom's packages are pinned to a specific commit and updated from release to
;; release. The `unpin!' macro allows you to unpin single packages...
;(unpin! pinned-package)
;; ...or multiple packages
;(unpin! pinned-package another-pinned-package)
;; ...Or *all* packages (NOT RECOMMENDED; will likely break things)
;(unpin! t)
;; treemacs-evil / treemacs-projectile are bundled with Doom's `:ui treemacs'
;; module, so they don't need to be declared here.
(package! exec-path-from-shell)

;; Drop Doom's non-LSP python backend: anaconda-mode pip-installs a bundled
;; jedi/parso env (crashes on Python 3.14) and pulls in the anaconda stack we
;; want to avoid.  Editing relies on tree-sitter + Homebrew python + uv; add
;; `(python +lsp)' with basedpyright later if smart completion is wanted.
(package! anaconda-mode :disable t)
(package! company-anaconda :disable t)

;; MELPA dropped the standalone `git-commit' recipe (magit 4.x folded it into
;; magit), which breaks `doom sync' on this older Doom.  git-commit.el still
;; ships inside the magit repo, so point straight there directly.  Shares the
;; already-cloned magit checkout, so it tracks magit's pinned commit.
(package! git-commit
  :recipe (:host github :repo "magit/magit" :files ("lisp/git-commit.el")))

(package! tldr)
(package! stan-mode)
(package! company-stan)
(package! eldoc-stan)
(package! flycheck-stan)
(package! stan-snippets)
;;(package! quarto-mode)
;; (package! ac-stan)
