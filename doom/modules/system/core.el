;;; system/core.el -*- lexical-binding: t; -*-

(setq user-full-name "Iwan-Dyke")

(defvar workbench/profile
  (let ((profile (or (getenv "WORKBENCH_PROFILE") "personal")))
    (if (member profile '("personal" "work"))
        profile
      "personal"))
  "Active Emacs Workbench profile.")

(defun workbench/show-profile ()
  "Show the active Emacs Workbench profile."
  (interactive)
  (message "Workbench profile: %s" workbench/profile))
