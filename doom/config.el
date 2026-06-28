;;; config.el -*- lexical-binding: t; -*-

(load! "modules/system/core")
(load! "modules/system/interface")
(load! "modules/tools/files")
(load! "modules/tools/git")
(load! "modules/tools/terminals")
(load! "modules/tools/languages")
(load! "modules/tools/formatting")
(load! "modules/workflows/coding")
(load! "modules/workflows/ai")
(load! "modules/workflows/session")
(load! "modules/system/keybindings")

;; Fix: flycheck elisp checker passes `t' to doom-initialize, but the current
;; signature expects (PROFILE-ID &optional INTERACTIVE?). Patch the subprocess
;; init to pass the profile ID string instead.
(defadvice! +workbench--fix-flycheck-elisp-doom-init-a (&rest _)
  "Replace `(doom-initialize t)' with `(doom-initialize PROFILE t)' in check form."
  :after #'+emacs-lisp--flycheck-non-package-mode
  (when (and (bound-and-true-p +emacs-lisp--flycheck-non-package-mode)
             (local-variable-p 'flycheck-emacs-lisp-check-form))
    (setq-local flycheck-emacs-lisp-check-form
                (replace-regexp-in-string
                 "(doom-initialize t)"
                 (format "(doom-initialize \"%s\" t)" (doom-profile-name doom-profile))
                 flycheck-emacs-lisp-check-form t t))))
