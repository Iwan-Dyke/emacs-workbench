;;; workflows/ai.el -*- lexical-binding: t; -*-

(require 'seq)
(declare-function workbench--project-root "modules/tools/files")
(declare-function workbench--treemacs-window "modules/system/interface")

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

(defun workbench--launch-vterm-agent (buffer-name tool)
  "Launch TOOL in a fresh vterm BUFFER-NAME in the current window.
Creates the buffer, resizes it, and sends the launch command after a
brief delay to allow vterm to initialise."
  (let ((new-buf (vterm buffer-name)))
    (workbench--vterm-resize new-buf (selected-window))
    (let ((b new-buf) (w (selected-window)) (cmd (workbench--ai-command tool)))
      (run-at-time 0.05 nil
                   (lambda ()
                     (when (and (buffer-live-p b) (window-live-p w))
                       (with-current-buffer b
                         (workbench--vterm-resize b w)
                         (vterm-send-string cmd)
                         (vterm-send-return))))))))

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
        (workbench--launch-vterm-agent buffer-name tool))
       ;; No buffer — create fresh
       (t
        (workbench--launch-vterm-agent buffer-name tool))))
    (delete-other-windows)))

(defun workbench/open-default-ai-workspace ()
  "Open the profile default AI agent full-window in the \"ai\" workspace."
  (interactive)
  (workbench--open-agent-workspace workbench/default-ai-tool))

;; Modelled on the user's Neovim toggleterm AI terminals (ADR 0048; see also
;; ADR 0034, ADR 0035). Each workspace gets its own AI pane buffer so switching
;; workspaces doesn't bleed context between projects.

(defvar workbench-project-ai-width 0.30
  "Width of the project AI pane as a fraction of the *available* editing area.
This fraction is applied to the frame width minus any side windows (e.g.
Treemacs), so the code buffer keeps a consistent proportion regardless of
whether the project tree is open.")

(defun workbench--ai-pane-window-width ()
  "Compute the AI pane width in columns, accounting for side windows.
Returns a column count (integer) so `display-buffer' doesn't miscalculate
when Treemacs is consuming part of the frame."
  (let* ((frame-cols (frame-width))
         (tree-cols (if-let ((tw (workbench--treemacs-window)))
                       (window-total-width tw)
                     0))
         (available (- frame-cols tree-cols)))
    (max 40 (round (* available workbench-project-ai-width)))))

(defun workbench--project-ai-buffer-name (tool)
  "Return the project AI buffer name for TOOL scoped to the current workspace."
  (format "*project-%s:%s*" tool (+workspace-current-name)))

(defun workbench--project-ai-window ()
  "Return a visible window showing any project AI buffer for this workspace, or nil.
Only searches the selected frame to avoid affecting panes on other frames."
  (let ((ws (+workspace-current-name)))
    (seq-some (lambda (tool)
                (when-let ((buffer (get-buffer (format "*project-%s:%s*" tool ws))))
                  (get-buffer-window buffer (selected-frame))))
              (mapcar #'car workbench/ai-commands))))

(defun workbench--show-project-ai (tool)
  "Show TOOL as the far-right AI pane for the current workspace.
Hides any other project AI pane first so only one is visible (exclusive).
Launches at the project root so the agent sees the whole project."
  ;; Cancel any pending resize timer from a previous AI pane to prevent
  ;; accumulation on rapid toggle cycles.
  (when-let ((existing-buf (get-buffer (workbench--project-ai-buffer-name tool))))
    (when (buffer-live-p existing-buf)
      (with-current-buffer existing-buf
        (when (timerp workbench--ai-pane-resize-timer)
          (cancel-timer workbench--ai-pane-resize-timer)
          (setq workbench--ai-pane-resize-timer nil)))))
  (when-let ((other (workbench--project-ai-window)))
    (delete-window other))
  (let* ((buffer-name (workbench--project-ai-buffer-name tool))
         (command (workbench--ai-command tool))
         (existing (get-buffer buffer-name))
         (default-directory (workbench--project-root))
         ;; Detect dead buffer BEFORE display — kill and recreate so we
         ;; never show a dead buffer in the window.
         (buffer (cond
                  ((and existing (get-buffer-process existing)) existing)
                  (existing
                   (kill-buffer existing)
                   (get-buffer-create buffer-name))
                  (t (get-buffer-create buffer-name))))
         (needs-launch (not (and existing (get-buffer-process existing))))
         (window (display-buffer
                  buffer
                  `((display-buffer-in-direction)
                    (direction . right)
                    (window . root)
                    (window-width . ,(workbench--ai-pane-window-width))))))
    (select-window window)
    (if (not needs-launch)
        ;; Existing buffer with live process — resize with retry
        (workbench--ai-pane-ensure-resize buffer window)
      (let ((root (workbench--project-root)))
        (with-current-buffer buffer
          (setq default-directory root)
          (vterm-mode)
          (workbench--vterm-resize buffer window)
          ;; Delay command send until vterm has processed the resize.
          (let ((buf buffer) (win window) (cmd command))
            (run-at-time 0.05 nil
                         (lambda ()
                           (when (and (buffer-live-p buf) (window-live-p win))
                             (with-current-buffer buf
                               (workbench--vterm-resize buf win)
                               (vterm-send-string cmd)
                               (vterm-send-return))))))
          (workbench--ai-pane-ensure-resize buffer window))))))


(defvar-local workbench--ai-pane-resize-timer nil
  "Pending resize retry timer for an AI pane buffer.")

(defvar-local workbench--ai-pane-resize-window nil
  "The window the AI pane is displayed in, used by the resize retrier.")

(defun workbench--ai-pane-ensure-resize (buffer window)
  "Ensure BUFFER's vterm pty matches WINDOW dimensions via retry-with-backoff.
Attempts resize immediately, then retries at 0.1s, 0.5s, and 2s. Stops
as soon as the pty dimensions match the window (or after 4 attempts).
Replaces the previous 5-path timing approach with a single mechanism."
  (with-current-buffer buffer
    ;; Cancel any existing retry from a previous toggle
    (when (timerp workbench--ai-pane-resize-timer)
      (cancel-timer workbench--ai-pane-resize-timer)
      (setq workbench--ai-pane-resize-timer nil))
    (setq workbench--ai-pane-resize-window window)
    ;; Immediate resize
    (workbench--vterm-resize buffer window)
    ;; Schedule retries with backoff
    (let ((buf buffer) (win window)
          (delays '(0.1 0.5 2.0)))
      (setq workbench--ai-pane-resize-timer
            (run-at-time
             (car delays) nil
             (lambda ()
               (workbench--ai-pane-resize-retry buf win (cdr delays))))))))

(defun workbench--ai-pane-resize-retry (buffer window remaining-delays)
  "Retry resizing BUFFER in WINDOW. Schedule next retry from REMAINING-DELAYS."
  (when (and (buffer-live-p buffer) (window-live-p window))
    (with-current-buffer buffer
      (workbench--vterm-resize buffer window)
      (if (null remaining-delays)
          (setq workbench--ai-pane-resize-timer nil)
        (setq workbench--ai-pane-resize-timer
              (run-at-time
               (car remaining-delays) nil
               (lambda ()
                 (workbench--ai-pane-resize-retry
                  buffer window (cdr remaining-delays)))))))))

(defun workbench--toggle-project-ai (tool)
  "Toggle TOOL as the project AI pane for the current workspace."
  (let* ((buffer-name (workbench--project-ai-buffer-name tool))
         (window (and (get-buffer buffer-name)
                      (get-buffer-window buffer-name (selected-frame)))))
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

(defvar workbench--vterm-resize-timer nil
  "Debounce timer for vterm resize sync.")

(defun workbench--sync-vterm-size (&optional frame)
  "Resize all visible vterm buffers to match their current window.
Debounced: schedules the actual resize after 0.05s idle to avoid excessive
calls during interactive window dragging."
  (when (timerp workbench--vterm-resize-timer)
    (cancel-timer workbench--vterm-resize-timer))
  (let ((f (or frame (selected-frame))))
    (setq workbench--vterm-resize-timer
          (run-with-idle-timer
           0.05 nil
           (lambda ()
             (setq workbench--vterm-resize-timer nil)
             (when (frame-live-p f)
               (dolist (window (window-list f))
                 (let ((buf (window-buffer window)))
                   (when (and (buffer-live-p buf)
                              (window-live-p window)
                              (with-current-buffer buf
                                (and (derived-mode-p 'vterm-mode)
                                     (boundp 'vterm--term)
                                     vterm--term)))
                     (workbench--vterm-resize buf window))))))))))

(add-hook 'window-size-change-functions #'workbench--sync-vterm-size)
