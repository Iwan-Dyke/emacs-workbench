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

;; Project/layout AI: the right-side pane in the coding layout (ADR 0034).
;; Distinct from the global/session AI buffers above; named *project-<tool>*
;; (ADR 0035). Owned by the coding workflow (ADR 0039).

(defun workbench--open-project-ai (buffer-name command)
  "Open BUFFER-NAME as a right-side AI vterm, running COMMAND on creation.
Focuses the pane if it already exists rather than restarting it."
  (let* ((existing (get-buffer buffer-name))
         (buffer (or existing (get-buffer-create buffer-name)))
         (window (display-buffer-in-side-window
                  buffer '((side . right) (window-width . 0.33)))))
    (select-window window)
    (unless existing
      (vterm-mode)
      (vterm-send-string command)
      (vterm-send-return))))

(defun workbench/open-project-codex ()
  "Open Codex as the project AI pane."
  (interactive)
  (workbench--open-project-ai "*project-codex*" "codex"))

(defun workbench/open-project-kiro ()
  "Open Kiro as the project AI pane."
  (interactive)
  (workbench--open-project-ai "*project-kiro*" "kiro"))

(defun workbench/open-project-claude ()
  "Open Claude as the project AI pane."
  (interactive)
  (workbench--open-project-ai "*project-claude*" "claude"))

(defun workbench/open-project-ai ()
  "Open the profile default AI as the project right-side pane (ADR 0034)."
  (interactive)
  (pcase workbench/default-ai-tool
    ("codex" (workbench/open-project-codex))
    ("kiro" (workbench/open-project-kiro))
    ("claude" (workbench/open-project-claude))
    (_ (user-error "Unknown default AI tool: %s" workbench/default-ai-tool))))
