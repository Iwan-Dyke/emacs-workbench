;;; config.el -*- lexical-binding: t; -*-

(load! "modules/system/core")
(load! "modules/system/interface")
(load! "modules/tools/files")
(load! "modules/tools/git")
(load! "modules/tools/terminals")
(load! "modules/tools/languages")
(load! "modules/tools/formatting")
(load! "modules/workflows/coding")
(load! "modules/workflows/project-dashboard")
(load! "modules/workflows/ai")
(load! "modules/workflows/session")
(load! "modules/system/keybindings")

;; Override: upstream passes `t' to doom-initialize but the current signature
;; expects (PROFILE-ID &optional INTERACTIVE?).
(after! flycheck
  (define-minor-mode +emacs-lisp--flycheck-non-package-mode
    "Reduced flycheck verbosity for non-package elisp buffers."
    :since "23.10"
    (if (not +emacs-lisp--flycheck-non-package-mode)
        (when (get 'flycheck-disabled-checkers 'initial-value)
          (setq-local flycheck-disabled-checkers (get 'flycheck-disabled-checkers 'initial-value))
          (kill-local-variable 'flycheck-emacs-lisp-check-form))
      (with-memoization (get 'flycheck-disabled-checkers 'initial-value)
        flycheck-disabled-checkers)
      (setq-local flycheck-emacs-lisp-check-form
                  (prin1-to-string
                   `(progn
                      (setq doom-modules ',doom-modules
                            doom-disabled-packages ',doom-disabled-packages
                            byte-compile-warnings ',+emacs-lisp-linter-warnings)
                      (condition-case e
                          (progn
                            (require 'doom)
                            (require 'doom-cli)
                            (doom-initialize ,(doom-profile-name doom-profile) t)
                            (doom-startup))
                        (error
                         (princ
                          (format "%s:%d:%d:Error:Failed to load Doom: %s\n"
                                  (or ,(ignore-errors
                                         (file-name-nondirectory
                                          (buffer-file-name (buffer-base-buffer))))
                                      (car command-line-args-left))
                                  0 0 (error-message-string e)))))
                      ,(read (default-toplevel-value 'flycheck-emacs-lisp-check-form))))
                  flycheck-disabled-checkers
                  (cons 'emacs-lisp-checkdoc
                        (remq 'emacs-lisp-checkdoc
                              flycheck-disabled-checkers))))))
