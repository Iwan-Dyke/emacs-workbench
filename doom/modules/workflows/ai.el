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

;; Project/layout AI: the right-side pane in the coding layout (ADR 0034),
;; modelled on the user's Neovim toggleterm AI terminals (ADR 0048) — a
;; 25-column vertical pane on the far right, toggled, exclusive, focus-taking.
;; Distinct from the global/session AI above; *project-<tool>* buffers (ADR 0035).

(defconst workbench-project-ai-buffers
  '("*project-codex*" "*project-kiro*" "*project-claude*")
  "All project AI pane buffer names.")

(defvar workbench-project-ai-width 0.4
  "Width of the project AI pane.
An integer is a column count; a float is a fraction of the frame width.")

(defun workbench--project-ai-window ()
  "Return a visible window showing any project AI buffer, or nil."
  (seq-some (lambda (name)
              (when-let ((buffer (get-buffer name)))
                (get-buffer-window buffer)))
            workbench-project-ai-buffers))

(defun workbench--show-project-ai (buffer-name command)
  "Show BUFFER-NAME as the far-right AI pane, creating it with COMMAND.
Hides any other project AI pane first so only one is visible (exclusive)."
  (when-let ((other (workbench--project-ai-window)))
    (delete-window other))
  (let* ((existing (get-buffer buffer-name))
         (buffer (or existing (get-buffer-create buffer-name)))
         (window (display-buffer
                  buffer
                  `((display-buffer-in-direction)
                    (direction . right)
                    (window . root)
                    (window-width . ,workbench-project-ai-width)))))
    (select-window window)
    (unless existing
      (vterm-mode)
      (vterm-send-string command)
      (vterm-send-return))))

(defun workbench--toggle-project-ai (buffer-name command)
  "Toggle BUFFER-NAME as the project AI pane running COMMAND."
  (let ((window (and (get-buffer buffer-name)
                     (get-buffer-window buffer-name))))
    (if window
        (delete-window window)
      (workbench--show-project-ai buffer-name command))))

(defun workbench/toggle-project-codex ()
  "Toggle Codex as the project AI pane."
  (interactive)
  (workbench--toggle-project-ai "*project-codex*" "codex"))

(defun workbench/toggle-project-kiro ()
  "Toggle Kiro as the project AI pane."
  (interactive)
  (workbench--toggle-project-ai "*project-kiro*" "kiro"))

(defun workbench/toggle-project-claude ()
  "Toggle Claude as the project AI pane."
  (interactive)
  (workbench--toggle-project-ai "*project-claude*" "claude"))

(defun workbench/toggle-project-ai ()
  "Toggle the profile default AI as the project pane (ADR 0034)."
  (interactive)
  (pcase workbench/default-ai-tool
    ("codex" (workbench/toggle-project-codex))
    ("kiro" (workbench/toggle-project-kiro))
    ("claude" (workbench/toggle-project-claude))
    (_ (user-error "Unknown default AI tool: %s" workbench/default-ai-tool))))
