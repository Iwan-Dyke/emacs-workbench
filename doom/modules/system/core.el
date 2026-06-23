;;; system/core.el -*- lexical-binding: t; -*-

(setq user-full-name "Iwan-Dyke")

(defvar workbench/profile
  (let ((profile (or (getenv "WORKBENCH_PROFILE") "personal")))
    (if (member profile '("personal" "work"))
        profile
      "personal"))
  "Active Emacs Workbench profile.")

(defun workbench--load-profile-file (file)
  "Load profile FILE from the workbench profiles directory when it exists."
  (let ((path (expand-file-name file (expand-file-name "profiles" doom-user-dir))))
    (when (file-exists-p path)
      (load! path))))

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

(defun workbench/close-frame ()
  "Close the selected Emacs frame."
  (interactive)
  (delete-frame))

(defun workbench/stop-daemon ()
  "Stop the current Emacs workbench daemon."
  (interactive)
  (save-buffers-kill-emacs))
