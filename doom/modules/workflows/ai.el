;;; workflows/ai.el -*- lexical-binding: t; -*-

(defun workbench--open-vterm-command (buffer-name command)
  "Open BUFFER-NAME in vterm and run COMMAND when creating it."
  (if (get-buffer buffer-name)
      (pop-to-buffer buffer-name)
    (let ((buffer (vterm buffer-name)))
      (with-current-buffer buffer
        (vterm-send-string command)
        (vterm-send-return)))))

(defun workbench/open-codex ()
  "Open Codex in a workbench terminal."
  (interactive)
  (workbench--open-vterm-command "*codex*" "codex"))

(defun workbench/open-kiro ()
  "Open Kiro in a workbench terminal."
  (interactive)
  (workbench--open-vterm-command "*kiro*" "kiro"))

(defun workbench/open-claude ()
  "Open Claude in a workbench terminal."
  (interactive)
  (workbench--open-vterm-command "*claude*" "claude"))

(defun workbench/open-default-ai ()
  "Open the default AI tool for the active workbench profile."
  (interactive)
  (pcase workbench/default-ai-tool
    ("codex" (workbench/open-codex))
    ("kiro" (workbench/open-kiro))
    ("claude" (workbench/open-claude))
    (_ (user-error "Unknown default AI tool: %s" workbench/default-ai-tool))))
