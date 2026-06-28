;;; system/core.el -*- lexical-binding: t; -*-

;; Error handling convention for workbench modules:
;; - Interactive commands signal `user-error' (clean message, no debugger).
;; - Internal functions let errors propagate — don't catch unless you can
;;   handle meaningfully (Henney).
;; - `condition-case' only where recovery is possible (e.g. windmove fallback).

(global-auto-revert-mode +1)

(defvar workbench/profile
  (let ((profile (or ;; Prefer daemon name — env var is unreliable across macOS daemon restarts
                     (let ((name (daemonp)))
                       (when (and (stringp name)
                                  (string-prefix-p "workbench-" name))
                         (substring name (length "workbench-"))))
                     (getenv "WORKBENCH_PROFILE")
                     "personal")))
    (if (member profile '("personal" "work"))
        profile
      "personal"))
  "Active Emacs Workbench profile.")

(defun workbench--load-profile-file (file)
  "Load profile FILE from the workbench profiles directory when it exists."
  (let ((path (expand-file-name file (expand-file-name "profiles" doom-user-dir))))
    (when (file-exists-p path)
      (load path nil 'nomessage))))

(defvar workbench/default-ai-tool "claude"
  "Default AI tool for the active workbench profile. Overridden by profile files.")

(workbench--load-profile-file (concat workbench/profile ".el"))
(workbench--load-profile-file "local.el")
(workbench--load-profile-file "secrets.el")

(defun workbench/show-profile ()
  "Show the active Emacs Workbench profile."
  (interactive)
  (message "Workbench profile: %s" workbench/profile))

(defun workbench/show-default-ai-tool ()
  "Show the default AI tool for the active workbench profile."
  (interactive)
  (message "Workbench default AI tool: %s" workbench/default-ai-tool))

