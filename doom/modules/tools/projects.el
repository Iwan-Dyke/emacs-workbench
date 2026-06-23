;;; tools/projects.el -*- lexical-binding: t; -*-

(defun workbench/switch-project ()
  "Switch to a known project."
  (interactive)
  (project-switch-project nil))

(defun workbench/find-project-file ()
  "Find a file in the current project."
  (interactive)
  (project-find-file))

(defun workbench/search-project ()
  "Search the current project."
  (interactive)
  (project-find-regexp))
