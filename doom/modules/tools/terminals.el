;;; tools/terminals.el -*- lexical-binding: t; -*-

(defun workbench/open-terminal ()
  "Open the main workbench terminal."
  (interactive)
  (vterm "*workbench-terminal*"))
