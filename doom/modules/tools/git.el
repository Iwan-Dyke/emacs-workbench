;;; tools/git.el -*- lexical-binding: t; -*-

(defun workbench/open-git ()
  "Open Magit for the current project."
  (interactive)
  (magit-status (workbench--project-root)))
