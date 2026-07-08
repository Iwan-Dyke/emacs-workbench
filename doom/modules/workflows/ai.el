;;; workflows/ai.el -*- lexical-binding: t; -*-

(require 'seq)
(declare-function workbench--project-root "modules/tools/files")

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

(defvar workbench-project-ai-width 0.30
  "Width of the project AI pane as a fraction of the frame (ADR 0048).")

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
Hides any other project AI pane first so only one is visible (exclusive).
Launches at the project root so the agent sees the whole project."
  (when-let ((other (workbench--project-ai-window)))
    (delete-window other))
  (let* ((buffer-name (workbench--project-ai-buffer-name tool))
         (command (workbench--ai-command tool))
         (existing (get-buffer buffer-name))
         (default-directory (workbench--project-root))
         (buffer (or existing (get-buffer-create buffer-name)))
         (window (display-buffer
                  buffer
                  `((display-buffer-in-direction)
                    (direction . right)
                    (window . root)
                    (window-width . ,workbench-project-ai-width)))))
    (select-window window)
    (if existing
        (workbench--vterm-resize buffer window)
      (with-current-buffer buffer
        (vterm-mode)
        (workbench--vterm-resize buffer window)
        (vterm-send-string command)
        (vterm-send-return)
        ;; CLI tools (kiro-cli, claude) take variable time to initialize.
        ;; A single delayed resize often fires before the child process is
        ;; ready to receive SIGWINCH. Use staggered timers to catch the
        ;; process at whatever stage it becomes responsive, plus a
        ;; process-output hook for the earliest reliable moment.
        (workbench--schedule-ai-pane-resizes buffer window)))))


(defvar-local workbench--ai-pane-resize-timer nil
  "Pending resize timer for an AI pane buffer.")

(defvar-local workbench--ai-pane-resize-done nil
  "Non-nil once the AI pane has confirmed a successful resize via output.")

(defvar-local workbench--ai-pane-resize-window nil
  "The window the AI pane is displayed in, used by the output resizer.")

(defun workbench--schedule-ai-pane-resizes (buffer window)
  "Schedule a delayed resize for BUFFER displayed in WINDOW.
Also hooks into process output so the resize fires the instant the
CLI tool writes its first output (proving it's alive). The 5s timer
is a fallback in case the output hook doesn't fire."
  (with-current-buffer buffer
    (setq workbench--ai-pane-resize-done nil)
    (setq workbench--ai-pane-resize-window window)
    (let ((buf buffer) (win window))
      (setq workbench--ai-pane-resize-timer
            (run-at-time 5.0 nil
                         (lambda ()
                           (when (and (buffer-live-p buf) (window-live-p win))
                             (workbench--vterm-resize buf win)
                             ;; Clean up the output filter if it never fired.
                             (when (and (buffer-live-p buf)
                                        (not (buffer-local-value
                                              'workbench--ai-pane-resize-done buf)))
                               (workbench--ai-pane-remove-output-filter buf))))))
      ;; Defer attaching the output filter — vterm replaces its process
      ;; filter during init, so adding immediately would be silently lost.
      (run-at-time 0.1 nil
                   (lambda ()
                     (when (buffer-live-p buf)
                       (when-let ((proc (get-buffer-process buf)))
                         (add-function :after (process-filter proc)
                                       #'workbench--ai-pane-output-resize-filter
                                       '((name . workbench-ai-resize))))))))))

(defun workbench--ai-pane-remove-output-filter (buffer)
  "Safely remove the resize output filter from BUFFER's process.
No-op if the process is dead or the filter was already removed."
  (ignore-errors
    (when-let ((proc (and (buffer-live-p buffer)
                          (get-buffer-process buffer))))
      (when (process-live-p proc)
        (remove-function (process-filter proc)
                         #'workbench--ai-pane-output-resize-filter)))))

(defun workbench--ai-pane-output-resize-filter (proc _output)
  "Resize the AI pane on first process output, then remove self.
Uses buffer-local variables to find the target window and state."
  (when-let ((buf (process-buffer proc)))
    (when (and (buffer-live-p buf)
               (not (buffer-local-value 'workbench--ai-pane-resize-done buf)))
      (with-current-buffer buf
        (let ((win workbench--ai-pane-resize-window))
          (when (window-live-p win)
            (setq workbench--ai-pane-resize-done t)
            (workbench--vterm-resize buf win)
            ;; Cancel the fallback timer.
            (when (timerp workbench--ai-pane-resize-timer)
              (cancel-timer workbench--ai-pane-resize-timer)
              (setq workbench--ai-pane-resize-timer nil))
            ;; Remove ourselves from the process filter.
            (workbench--ai-pane-remove-output-filter buf)))))))

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

;; Vterm buffers are read-only, so resizing the libvterm grid requires
;; inhibit-read-only. Without this, vterm--set-size silently fails and the
;; pty keeps its stale column count.
(defun workbench--vterm-resize (buffer window)
  "Resize vterm BUFFER to match WINDOW dimensions."
  (with-current-buffer buffer
    (when (and (boundp 'vterm--term) vterm--term)
      (let ((inhibit-read-only t)
            (h (window-body-height window))
            (w (window-body-width window)))
        (vterm--set-size vterm--term h w)
        (when-let ((proc (get-buffer-process buffer)))
          (set-process-window-size proc h w))))))

(defun workbench--sync-vterm-size (&optional frame)
  "Resize all visible vterm buffers to match their current window."
  (dolist (window (window-list (or frame (selected-frame))))
    (let ((buf (window-buffer window)))
      (when (and (buffer-live-p buf)
                 (with-current-buffer buf
                   (and (derived-mode-p 'vterm-mode)
                        (boundp 'vterm--term)
                        vterm--term)))
        (workbench--vterm-resize buf window)))))

(add-hook 'window-size-change-functions #'workbench--sync-vterm-size)
