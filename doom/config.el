;;; config.el -*- lexical-binding: t; -*-

;; ── Module Load Order ─────────────────────────────────────────────────────────
;;
;; Modules are loaded in dependency order. Rules:
;;   1. system/core MUST load first (provides profile, defvars)
;;   2. tools/shell MUST precede tools/jira and workflows/* (shell helpers)
;;   3. tools/popup MUST precede tools/git and tools/terminals (popup infra)
;;   4. tools/async-eval MUST precede tools/jira and workflows/command-centre
;;   5. tools/files MUST precede workflows/* (project-root, treemacs)
;;   6. tools/jira MUST precede workflows/org and workflows/command-centre
;;   7. workflows/coding MUST precede workflows/session (workspace ops)
;;   8. workflows/ai MUST precede workflows/coding (project AI pane)
;;   9. system/keybindings MUST load last (references all other modules)
;;
;; Do NOT reorder without checking these constraints.

(load! "modules/system/core")
(load! "modules/system/interface")
(load! "modules/system/visual")
(load! "modules/tools/shell")
(load! "modules/tools/popup")
(load! "modules/tools/async-eval")
(load! "modules/tools/files")
(load! "modules/tools/git")
(load! "modules/tools/terminals")
(load! "modules/tools/languages")
(load! "modules/tools/mermaid")
(load! "modules/tools/formatting")
(load! "modules/tools/jira")
(load! "modules/workflows/coding")
(load! "modules/workflows/project-dashboard")
(load! "modules/workflows/repos")
(load! "modules/workflows/ai")
(load! "modules/workflows/org")
(load! "modules/workflows/session")
(load! "modules/workflows/command-centre")
(load! "modules/system/keybindings")

;; ── Flycheck override ────────────────────────────────────────────────────────
;;
;; Copied from: Doom's modules/lang/emacs-lisp/autoload.el
;; Doom commit:  2024-06-xx (pre doom-initialize signature change)
;; Why:          Upstream passes `t' to doom-initialize but the current
;;               signature expects (PROFILE-ID &optional INTERACTIVE?).
;; Audit:        CHECK ON EVERY `doom upgrade'. Remove when upstream fixes the
;;               signature mismatch in +emacs-lisp--flycheck-non-package-mode.
;; Last checked: 2026-08-23
;;
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
