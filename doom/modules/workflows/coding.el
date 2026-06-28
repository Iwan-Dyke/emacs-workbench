;;; workflows/coding.el -*- lexical-binding: t; -*-

(declare-function workbench--directory-name "modules/tools/files")
(declare-function workbench/open-selected-path-as-project-workspace "modules/tools/files")

(defun workbench--project-identity-name (directory)
  "Return a workspace name for DIRECTORY: the bare directory name.
If a workspace with that name already exists for a different directory,
appends a numeric suffix (e.g. utils<2>)."
  (let* ((path (directory-file-name (file-truename directory)))
         (base (file-name-nondirectory path)))
    (if (or (not (fboundp '+workspace-exists-p))
            (not (+workspace-exists-p base)))
        base
      ;; Name taken — check if it's the same directory (reopen) or a collision.
      (let ((existing-dir
             (when-let ((buf (get-buffer (format "*workbench:%s*" base))))
               (buffer-local-value 'default-directory buf))))
        (if (and existing-dir (string= (file-truename existing-dir) path))
            base
          ;; Collision — find next available suffix
          (let ((n 2) candidate)
            (while (progn
                     (setq candidate (format "%s<%d>" base n))
                     (+workspace-exists-p candidate))
              (setq n (1+ n)))
            candidate))))))

(defun workbench/open-project-dashboard (directory)
  "Open the project dashboard for DIRECTORY."
  (let* ((project-directory (file-truename directory))
         (project-name (workbench--directory-name project-directory))
         (project-identity (workbench--project-identity-name project-directory))
         (buffer (get-buffer-create (format "*workbench:%s*" project-identity))))
    (switch-to-buffer buffer)
    (special-mode)
    (setq-local default-directory project-directory)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert project-name "\n")
      (insert (abbreviate-file-name project-directory) "\n"))))

(defun workbench/open-project-workspace (directory)
  "Open DIRECTORY as a workbench project workspace.
Creates the workspace and lands on the project placeholder. The tree
\(SPC e) and the project AI pane are summoned on demand (ADR 0044)."
  (interactive "DProject directory: ")
  (let* ((project-directory (file-truename directory))
         (workspace-name (workbench--project-identity-name project-directory)))
    (if (fboundp '+workspace-switch)
        (+workspace-switch workspace-name t)
      (user-error "Doom workspaces are not available"))
    (setq default-directory project-directory)
    (workbench/open-project-dashboard project-directory)))

(defun workbench/open-project-workspace-dwim ()
  "Open a project workspace from the selected path, or by prompting."
  (interactive)
  (if (derived-mode-p 'dired-mode)
      (workbench/open-selected-path-as-project-workspace)
    (call-interactively #'workbench/open-project-workspace)))
