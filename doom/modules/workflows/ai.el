;;; workflows/ai.el -*- lexical-binding: t; -*-

(require 'seq)

;; Two AI scopes (ADR 0034). Global/session agents run full-window in the "ai"
;; workspace; project AI panes dock on the far right of a coding layout
;; (ADR 0048). Buffer names: *<tool>* for session agents,
;; *project-<tool>:<workspace>* for workspace-scoped panes.

(defvar workbench/ai-commands
  '(("claude" . "claude")
    ("kiro"   . "kiro-cli")
    ("codex"  . "codex"))
  "Alist mapping an AI tool name to its launch command.")

(defun workbench--ai-command (tool)
  "Return the launch command string for TOOL."
  (or (cdr (assoc tool workbench/ai-commands))
      (user-error "No command configured for AI tool: %s" tool)))

(defun workbench--open-agent-workspace (tool)
  "Open TOOL full-window in the \"ai\" workspace, launching it once.
If the buffer exists but the process is dead, kills and relaunches it."
  (let ((buffer-name (format "*%s*" tool)))
    (+workspace-switch "ai" t)
    (let ((buf (get-buffer buffer-name)))
      (cond
       ;; Live buffer with running process — just switch to it
       ((and buf (get-buffer-process buf))
        (switch-to-buffer buf))
       ;; Dead buffer — kill and relaunch
       (buf
        (kill-buffer buf)
        (vterm buffer-name)
        (vterm-send-string (workbench--ai-command tool))
        (vterm-send-return))
       ;; No buffer — create fresh
       (t
        (vterm buffer-name)
        (vterm-send-string (workbench--ai-command tool))
        (vterm-send-return))))
    (delete-other-windows)))

(defun workbench/open-default-ai-workspace ()
  "Open the profile default AI agent full-window in the \"ai\" workspace."
  (interactive)
  (workbench--open-agent-workspace workbench/default-ai-tool))

;; Modelled on the user's Neovim toggleterm AI terminals (ADR 0048; see also
;; ADR 0034, ADR 0035). Each workspace gets its own AI pane buffer so switching
;; workspaces doesn't bleed context between projects.

(defvar workbench-project-ai-width 25
  "Width of the project AI pane in columns (ADR 0048).")

(defun workbench--project-ai-buffer-name (tool)
  "Return the project AI buffer name for TOOL scoped to the current workspace."
  (format "*project-%s:%s*" tool (+workspace-current-name)))

(defun workbench--project-ai-window ()
  "Return a visible window showing any project AI buffer for this workspace, or nil."
  (let ((ws (+workspace-current-name)))
    (seq-some (lambda (tool)
                (when-let ((buffer (get-buffer (format "*project-%s:%s*" tool ws))))
                  (get-buffer-window buffer)))
              '("codex" "kiro" "claude"))))

(defun workbench--show-project-ai (tool)
  "Show TOOL as the far-right AI pane for the current workspace.
Hides any other project AI pane first so only one is visible (exclusive)."
  (when-let ((other (workbench--project-ai-window)))
    (delete-window other))
  (let* ((buffer-name (workbench--project-ai-buffer-name tool))
         (command (workbench--ai-command tool))
         (existing (get-buffer buffer-name))
         (buffer (or existing (get-buffer-create buffer-name)))
         (window (display-buffer
                  buffer
                  `((display-buffer-in-direction)
                    (direction . right)
                    (window . root)
                    (window-width . ,workbench-project-ai-width)))))
    (select-window window)
    (unless existing
      (with-current-buffer buffer
        (vterm-mode)
        (vterm-send-string command)
        (vterm-send-return)))))

(defun workbench--toggle-project-ai (tool)
  "Toggle TOOL as the project AI pane for the current workspace."
  (let* ((buffer-name (workbench--project-ai-buffer-name tool))
         (window (and (get-buffer buffer-name)
                      (get-buffer-window buffer-name))))
    (if window
        (delete-window window)
      (workbench--show-project-ai tool))))

(defun workbench/toggle-project-codex ()
  "Toggle Codex as the project AI pane."
  (interactive)
  (workbench--toggle-project-ai "codex"))

(defun workbench/toggle-project-kiro ()
  "Toggle Kiro as the project AI pane."
  (interactive)
  (workbench--toggle-project-ai "kiro"))

(defun workbench/toggle-project-claude ()
  "Toggle Claude as the project AI pane."
  (interactive)
  (workbench--toggle-project-ai "claude"))

(defun workbench/toggle-project-ai ()
  "Toggle the profile default AI as the project pane (ADR 0034, ADR 0048)."
  (interactive)
  (workbench--toggle-project-ai workbench/default-ai-tool))
