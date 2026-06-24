;;; tools/terminals.el -*- lexical-binding: t; -*-

(defun workbench/open-terminal-workspace ()
  "Open a new workspace with a fresh terminal, like a tmux new window.
Type whatever you want in it: a shell command or an AI agent."
  (interactive)
  (+workspace/new)
  (vterm (generate-new-buffer-name "*terminal*")))
