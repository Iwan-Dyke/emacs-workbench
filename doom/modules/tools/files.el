;;; tools/files.el -*- lexical-binding: t; -*-

(defun workbench--project-root ()
  "Return the current project root, or `default-directory' when outside a project."
  (or (when-let ((project (project-current nil)))
        (project-root project))
      default-directory))

(defun workbench/open-files ()
  "Open the workbench file manager at the current project root."
  (interactive)
  (let ((directory (workbench--project-root)))
    (if (fboundp 'dirvish)
        (dirvish directory)
      (dired directory))))
