;;; workflows/ai.el -*- lexical-binding: t; -*-

;; Two AI scopes (ADR 0034). Global/session agents run full-window in the "ai"
;; workspace; project AI panes dock on the far right of a coding layout
;; (ADR 0048). Buffer names stay simple (ADR 0035): *<tool>* for session agents,
;; *project-<tool>* for the panes.

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
  "Open TOOL full-window in the \"ai\" workspace, launching it once."
  (let ((buffer-name (format "*%s*" tool)))
    (+workspace-switch "ai" t)
    (if (get-buffer buffer-name)
        (switch-to-buffer buffer-name)
      (vterm buffer-name)
      (vterm-send-string (workbench--ai-command tool))
      (vterm-send-return))
    (delete-other-windows)))

(defun workbench/open-default-ai-workspace ()
  "Open the profile default AI agent full-window in the \"ai\" workspace."
  (interactive)
  (workbench--open-agent-workspace workbench/default-ai-tool))

;; Modelled on the user's Neovim toggleterm AI terminals (ADR 0048; see also
;; ADR 0034, ADR 0035).

(defconst workbench-project-ai-buffers
  '("*project-codex*" "*project-kiro*" "*project-claude*")
  "All project AI pane buffer names.")

(defvar workbench-project-ai-width 25
  "Width of the project AI pane, matching the file tree (ADR 0048).
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
  (workbench--toggle-project-ai "*project-codex*" (workbench--ai-command "codex")))

(defun workbench/toggle-project-kiro ()
  "Toggle Kiro as the project AI pane."
  (interactive)
  (workbench--toggle-project-ai "*project-kiro*" (workbench--ai-command "kiro")))

(defun workbench/toggle-project-claude ()
  "Toggle Claude as the project AI pane."
  (interactive)
  (workbench--toggle-project-ai "*project-claude*" (workbench--ai-command "claude")))

(defun workbench/toggle-project-ai ()
  "Toggle the profile default AI as the project pane (ADR 0034, ADR 0048)."
  (interactive)
  (workbench--toggle-project-ai
   (format "*project-%s*" workbench/default-ai-tool)
   (workbench--ai-command workbench/default-ai-tool)))
