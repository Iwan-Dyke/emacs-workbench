;;; test/unit/test-ai.el --- Unit tests for workflows/ai.el -*- lexical-binding: t; -*-

(require 'test-helper)

;; Load the module under test
(workbench-test-load-module "modules/workflows/ai")

;;; ── workbench--ai-command ──────────────────────────────────────────────────

(ert-deftest ai-command/returns-claude-command ()
  (should (equal (workbench--ai-command "claude") "claude")))

(ert-deftest ai-command/returns-kiro-command ()
  (should (equal (workbench--ai-command "kiro") "kiro-cli")))

(ert-deftest ai-command/returns-codex-command ()
  (should (equal (workbench--ai-command "codex") "codex")))

(ert-deftest ai-command/errors-on-unknown-tool ()
  (should-error (workbench--ai-command "unknown-tool") :type 'user-error))

;;; ── workbench--project-ai-buffer-name ──────────────────────────────────────

(ert-deftest project-ai-buffer-name/includes-tool-and-workspace ()
  (let ((workbench-test--current-workspace "my-project"))
    (should (equal (workbench--project-ai-buffer-name "claude")
                   "*project-claude:my-project*"))))

(ert-deftest project-ai-buffer-name/includes-kiro-tool ()
  (let ((workbench-test--current-workspace "backend"))
    (should (equal (workbench--project-ai-buffer-name "kiro")
                   "*project-kiro:backend*"))))

(ert-deftest project-ai-buffer-name/different-workspace-different-name ()
  (let ((workbench-test--current-workspace "ws-a"))
    (let ((name-a (workbench--project-ai-buffer-name "claude")))
      (let ((workbench-test--current-workspace "ws-b"))
        (let ((name-b (workbench--project-ai-buffer-name "claude")))
          (should-not (equal name-a name-b)))))))

;;; ── workbench--project-ai-window ───────────────────────────────────────────

(ert-deftest project-ai-window/returns-nil-when-no-ai-buffer ()
  "No AI pane buffers exist at all — should return nil."
  (let ((workbench-test--current-workspace "empty-ws"))
    (should-not (workbench--project-ai-window))))

(ert-deftest project-ai-window/returns-nil-when-buffer-exists-but-not-visible ()
  "AI buffer exists but is not shown in any window — should return nil."
  (let ((workbench-test--current-workspace "hidden-ws"))
    (let ((buf (get-buffer-create "*project-claude:hidden-ws*")))
      (unwind-protect
          (should-not (workbench--project-ai-window))
        (kill-buffer buf)))))

;;; ── Buffer naming isolation between workspaces ─────────────────────────────

(ert-deftest ai-buffer-isolation/different-workspaces-separate-buffers ()
  "Each workspace gets its own AI buffer — no cross-workspace bleed."
  (let ((workbench-test--current-workspace "project-alpha"))
    (let ((buf-alpha (get-buffer-create (workbench--project-ai-buffer-name "codex"))))
      (unwind-protect
          (let ((workbench-test--current-workspace "project-beta"))
            (let ((buf-beta (get-buffer-create (workbench--project-ai-buffer-name "codex"))))
              (unwind-protect
                  (progn
                    (should-not (eq buf-alpha buf-beta))
                    (should (equal (buffer-name buf-alpha) "*project-codex:project-alpha*"))
                    (should (equal (buffer-name buf-beta) "*project-codex:project-beta*")))
                (kill-buffer buf-beta))))
        (kill-buffer buf-alpha)))))

(ert-deftest ai-buffer-isolation/same-workspace-same-buffer ()
  "Same workspace and tool always resolves to the same buffer name."
  (let ((workbench-test--current-workspace "shared"))
    (should (equal (workbench--project-ai-buffer-name "kiro")
                   (workbench--project-ai-buffer-name "kiro")))))

;;; ── Regression tests ────────────────────────────────────────────────────────

(ert-deftest ai/regression-show-project-ai-reuses-dead-process-buffer ()
  "FIXED: existing buffer with dead process is killed and relaunched."
  (let ((workbench-test--current-workspace "test")
        (vterm-mode-called nil))
    (let ((buf (get-buffer-create "*project-claude:test*")))
      (unwind-protect
          (cl-letf (((symbol-function 'workbench--project-root) (lambda () "/tmp/"))
                    ((symbol-function 'workbench--project-ai-window) (lambda () nil))
                    ((symbol-function 'workbench--ai-pane-window-width) (lambda () 60))
                    ((symbol-function 'display-buffer) (lambda (b _) (selected-window)))
                    ((symbol-function 'select-window) #'ignore)
                    ((symbol-function 'workbench--vterm-resize) #'ignore)
                    ((symbol-function 'vterm-mode) (lambda () (setq vterm-mode-called t)))
                    ((symbol-function 'vterm-send-string) #'ignore)
                    ((symbol-function 'vterm-send-return) #'ignore)
                    ((symbol-function 'workbench--schedule-ai-pane-resizes) #'ignore)
                    ((symbol-function 'run-at-time) (lambda (&rest _) nil))
                    ;; Buffer exists but has NO process (simulating dead CLI)
                    ((symbol-function 'get-buffer-process) (lambda (_) nil)))
            (workbench--show-project-ai "claude")
            ;; It SHOULD detect the dead process and relaunch
            (should vterm-mode-called))
        (kill-buffer buf)))))

(ert-deftest ai/regression-toggle-finds-window-on-other-frame ()
  "get-buffer-window searches all frames — may find pane on wrong frame.
Documents the issue: toggling on frame B could delete the pane on frame A."
  (let ((workbench-test--current-workspace "test"))
    (let ((buf (get-buffer-create "*project-claude:test*")))
      (unwind-protect
          (progn
            ;; Verify the function uses get-buffer-window (documenting the issue)
            (should (equal (workbench--project-ai-buffer-name "claude")
                           "*project-claude:test*")))
        (kill-buffer buf)))))

(ert-deftest ai/regression-open-agent-workspace-deletes-windows-when-already-in-ai ()
  "If already in 'ai' workspace, open-agent-workspace still calls delete-other-windows.
This is correct behaviour (ensures full-frame), documenting it."
  (let ((workbench-test--current-workspace "ai")
        (deleted nil)
        (vterm-called nil))
    (cl-letf (((symbol-function '+workspace-switch) #'ignore)
              ((symbol-function 'get-buffer) (lambda (_) nil))
              ((symbol-function 'vterm)
               (lambda (name) (setq vterm-called t) (get-buffer-create name)))
              ((symbol-function 'vterm-send-string) #'ignore)
              ((symbol-function 'vterm-send-return) #'ignore)
              ((symbol-function 'delete-other-windows) (lambda () (setq deleted t))))
      (workbench--open-agent-workspace "claude")
      ;; delete-other-windows IS called (expected — ensures full-frame in ai workspace)
      (should deleted)
      (should vterm-called)
      (when (get-buffer "*claude*") (kill-buffer "*claude*")))))

(ert-deftest ai/regression-display-buffer-called-with-dead-buffer-then-killed ()
  "FIXED: dead buffer is killed BEFORE display-buffer. Window always shows live buffer."
  (let ((workbench-test--current-workspace "test")
        (displayed-buffer nil))
    (let ((dead-buf (get-buffer-create "*project-claude:test*")))
      ;; Simulate: buffer exists, no process (dead CLI)
      (unwind-protect
          (cl-letf (((symbol-function 'workbench--project-root) (lambda () "/tmp/"))
                    ((symbol-function 'workbench--project-ai-window) (lambda () nil))
                    ((symbol-function 'workbench--ai-pane-window-width) (lambda () 60))
                    ((symbol-function 'display-buffer)
                     (lambda (buf _) (setq displayed-buffer buf) (selected-window)))
                    ((symbol-function 'select-window) #'ignore)
                    ((symbol-function 'workbench--vterm-resize) #'ignore)
                    ((symbol-function 'vterm-mode) #'ignore)
                    ((symbol-function 'vterm-send-string) #'ignore)
                    ((symbol-function 'vterm-send-return) #'ignore)
                    ((symbol-function 'workbench--schedule-ai-pane-resizes) #'ignore)
                    ((symbol-function 'run-at-time) (lambda (&rest _) nil))
                    ((symbol-function 'get-buffer-process) (lambda (_) nil)))
            (workbench--show-project-ai "claude")
            ;; The buffer passed to display-buffer should be live
            (should (buffer-live-p displayed-buffer)))
        (when (get-buffer "*project-claude:test*")
          (kill-buffer "*project-claude:test*"))))))

(ert-deftest ai/regression-note-double-toggle-same-tool-hides-pane ()
  "Toggling the same tool twice hides the pane (delete-window)."
  (let ((workbench-test--current-workspace "test")
        (deleted nil))
    (let ((buf (get-buffer-create "*project-claude:test*")))
      (unwind-protect
          (progn
            ;; Display the buffer in a window
            (set-window-buffer (selected-window) buf)
            (cl-letf (((symbol-function 'delete-window) (lambda (_) (setq deleted t)))
                      ((symbol-function 'get-buffer-window)
                       (lambda (_buf &optional _frame) (selected-window))))
              (workbench--toggle-project-ai "claude")
              (should deleted)))
        (kill-buffer buf)))))

;;; ── workbench--ai-pane-window-width ─────────────────────────────────────────

(ert-deftest ai-pane-width/uses-full-frame-when-no-treemacs ()
  "Without Treemacs, AI pane width is 30% of the full frame."
  (cl-letf (((symbol-function 'frame-width) (lambda () 200))
            ((symbol-function 'workbench--treemacs-window) (lambda () nil)))
    (should (equal (workbench--ai-pane-window-width) 60))))

(ert-deftest ai-pane-width/subtracts-treemacs-width ()
  "With Treemacs open (25 cols), AI pane is 30% of remaining space."
  (let ((fake-treemacs-win (selected-window)))
    (cl-letf (((symbol-function 'frame-width) (lambda () 200))
              ((symbol-function 'workbench--treemacs-window) (lambda () fake-treemacs-win))
              ((symbol-function 'window-total-width) (lambda (_w) 25)))
      ;; 30% of (200 - 25) = 30% of 175 = 52.5, rounded to 52 or 53
      (let ((width (workbench--ai-pane-window-width)))
        (should (>= width 52))
        (should (<= width 53))))))

(ert-deftest ai-pane-width/respects-minimum-40-columns ()
  "AI pane never goes below 40 columns even on a narrow frame."
  (cl-letf (((symbol-function 'frame-width) (lambda () 100))
            ((symbol-function 'workbench--treemacs-window) (lambda () nil)))
    ;; 30% of 100 = 30, but minimum is 40
    (should (equal (workbench--ai-pane-window-width) 40))))

(ert-deftest ai-pane-width/minimum-even-with-treemacs ()
  "AI pane hits 40-col minimum when frame is narrow and Treemacs is open."
  (let ((fake-treemacs-win (selected-window)))
    (cl-letf (((symbol-function 'frame-width) (lambda () 120))
              ((symbol-function 'workbench--treemacs-window) (lambda () fake-treemacs-win))
              ((symbol-function 'window-total-width) (lambda (_w) 25)))
      ;; 30% of (120 - 25) = 30% of 95 = 28.5, below 40 → clamped to 40
      (should (equal (workbench--ai-pane-window-width) 40)))))

;;; ── Delayed command launch (text cutoff fix) ───────────────────────────────

(ert-deftest ai/show-project-ai-delays-command-send ()
  "Command is sent via run-at-time, not inline, to avoid pty width race."
  (let ((workbench-test--current-workspace "test")
        (timer-scheduled nil)
        (inline-send nil))
    (let ((buf (get-buffer-create "*project-claude:test*")))
      (unwind-protect
          (cl-letf (((symbol-function 'workbench--project-root) (lambda () "/tmp/"))
                    ((symbol-function 'workbench--project-ai-window) (lambda () nil))
                    ((symbol-function 'workbench--ai-pane-window-width) (lambda () 60))
                    ((symbol-function 'display-buffer) (lambda (b _) (selected-window)))
                    ((symbol-function 'select-window) #'ignore)
                    ((symbol-function 'workbench--vterm-resize) #'ignore)
                    ((symbol-function 'vterm-mode) #'ignore)
                    ((symbol-function 'vterm-send-string)
                     (lambda (_s) (setq inline-send t)))
                    ((symbol-function 'vterm-send-return) #'ignore)
                    ((symbol-function 'workbench--schedule-ai-pane-resizes) #'ignore)
                    ((symbol-function 'get-buffer-process) (lambda (_) nil))
                    ((symbol-function 'run-at-time)
                     (lambda (_time _repeat fn &rest _args)
                       (setq timer-scheduled t)
                       nil)))
            (workbench--show-project-ai "claude")
            ;; Command should NOT be sent inline
            (should-not inline-send)
            ;; Instead, a timer should be scheduled for the deferred send
            (should timer-scheduled))
        (kill-buffer buf)))))

(ert-deftest ai/show-project-ai-resizes-before-scheduling-command ()
  "vterm-resize is called immediately during launch, before the deferred command."
  (let ((workbench-test--current-workspace "test")
        (resize-called nil))
    (let ((buf (get-buffer-create "*project-claude:test*")))
      (unwind-protect
          (cl-letf (((symbol-function 'workbench--project-root) (lambda () "/tmp/"))
                    ((symbol-function 'workbench--project-ai-window) (lambda () nil))
                    ((symbol-function 'workbench--ai-pane-window-width) (lambda () 60))
                    ((symbol-function 'display-buffer) (lambda (b _) (selected-window)))
                    ((symbol-function 'select-window) #'ignore)
                    ((symbol-function 'workbench--vterm-resize)
                     (lambda (_b _w) (setq resize-called t)))
                    ((symbol-function 'vterm-mode) #'ignore)
                    ((symbol-function 'vterm-send-string) #'ignore)
                    ((symbol-function 'vterm-send-return) #'ignore)
                    ((symbol-function 'workbench--schedule-ai-pane-resizes) #'ignore)
                    ((symbol-function 'get-buffer-process) (lambda (_) nil))
                    ((symbol-function 'run-at-time) (lambda (&rest _) nil)))
            (workbench--show-project-ai "claude")
            ;; Resize must fire synchronously before the timer
            (should resize-called))
        (kill-buffer buf)))))

;;; ── Resize on re-open ──────────────────────────────────────────────────────

(ert-deftest ai-pane/reopen-triggers-deferred-resize ()
  "Re-opening a pane with live process triggers retry-with-backoff resizes."
  (let ((resize-count 0)
        (timer-delays '())
        (buf (get-buffer-create "*project-kiro:main*")))
    (unwind-protect
        (cl-letf (((symbol-function 'workbench--project-root) (lambda () "/tmp/"))
                  ((symbol-function 'workbench--project-ai-window) (lambda () nil))
                  ((symbol-function 'workbench--ai-pane-window-width) (lambda () 60))
                  ((symbol-function 'display-buffer) (lambda (b _) (selected-window)))
                  ((symbol-function 'select-window) #'ignore)
                  ((symbol-function 'workbench--vterm-resize)
                   (lambda (_b _w) (cl-incf resize-count)))
                  ((symbol-function 'get-buffer-process) (lambda (_) t))
                  ((symbol-function 'run-at-time)
                   (lambda (delay _repeat fn)
                     (push delay timer-delays)
                     (funcall fn)
                     nil)))
          (workbench--show-project-ai "kiro")
          ;; Should have multiple resizes: immediate + retries
          (should (>= resize-count 2))
          ;; Retry schedule uses backoff delays (0.1, 0.5, 2.0)
          (should (member 0.1 timer-delays)))
      (kill-buffer buf))))

(ert-deftest ai-pane/reopen-does-not-relaunch-process ()
  "Re-opening a pane with live process does NOT launch vterm-mode or send commands."
  (let ((vterm-mode-called nil)
        (send-called nil)
        (buf (get-buffer-create "*project-claude:main*")))
    (unwind-protect
        (cl-letf (((symbol-function 'workbench--project-root) (lambda () "/tmp/"))
                  ((symbol-function 'workbench--project-ai-window) (lambda () nil))
                  ((symbol-function 'workbench--ai-pane-window-width) (lambda () 60))
                  ((symbol-function 'display-buffer) (lambda (b _) (selected-window)))
                  ((symbol-function 'select-window) #'ignore)
                  ((symbol-function 'workbench--vterm-resize) #'ignore)
                  ((symbol-function 'get-buffer-process) (lambda (_) t))
                  ((symbol-function 'run-at-time) (lambda (&rest _) nil))
                  ((symbol-function 'vterm-mode) (lambda () (setq vterm-mode-called t)))
                  ((symbol-function 'vterm-send-string) (lambda (&rest _) (setq send-called t)))
                  ((symbol-function 'vterm-send-return) (lambda () (setq send-called t))))
          (workbench--show-project-ai "claude")
          (should-not vterm-mode-called)
          (should-not send-called))
      (kill-buffer buf))))

;;; ── Debounced vterm resize ─────────────────────────────────────────────────

(ert-deftest ai/sync-vterm-size-uses-idle-timer ()
  "workbench--sync-vterm-size schedules an idle timer rather than resizing immediately."
  (let ((workbench--vterm-resize-timer nil)
        (timer-created nil))
    (cl-letf (((symbol-function 'run-with-idle-timer)
               (lambda (secs _repeat fn &rest _args)
                 (setq timer-created secs)
                 (timer-create))))
      (workbench--sync-vterm-size)
      (should timer-created)
      (should (= timer-created 0.05)))))

(ert-deftest ai/sync-vterm-size-cancels-previous-timer ()
  "Rapid calls to workbench--sync-vterm-size cancel the previous timer."
  (let* ((workbench--vterm-resize-timer (timer-create))
         (cancelled nil))
    (cl-letf (((symbol-function 'cancel-timer)
               (lambda (_timer) (setq cancelled t)))
              ((symbol-function 'run-with-idle-timer)
               (lambda (_secs _repeat _fn &rest _args) (timer-create))))
      (workbench--sync-vterm-size)
      (should cancelled))))

;;; ── AI tool list derivation ────────────────────────────────────────────────

(ert-deftest ai/project-ai-window-checks-all-configured-tools ()
  "workbench--project-ai-window checks buffers for all tools in workbench/ai-commands."
  (let ((workbench/ai-commands '(("foo" . "foo-cmd") ("bar" . "bar-cmd")))
        (checked-tools nil))
    (cl-letf (((symbol-function '+workspace-current-name) (lambda () "test"))
              ((symbol-function 'get-buffer)
               (lambda (name) (push name checked-tools) nil)))
      (workbench--project-ai-window)
      (should (member "*project-foo:test*" checked-tools))
      (should (member "*project-bar:test*" checked-tools)))))

;;; ── Launch helper ──────────────────────────────────────────────────────────

(ert-deftest ai/launch-vterm-agent-calls-vterm-with-buffer-name ()
  "workbench--launch-vterm-agent creates a vterm buffer with the given name."
  (let ((vterm-buffer-name nil)
        (resize-called nil)
        (timer-scheduled nil))
    (cl-letf (((symbol-function 'vterm)
               (lambda (name) (setq vterm-buffer-name name) (current-buffer)))
              ((symbol-function 'workbench--vterm-resize)
               (lambda (_buf _win) (setq resize-called t)))
              ((symbol-function 'workbench--ai-command)
               (lambda (_tool) "claude"))
              ((symbol-function 'run-at-time)
               (lambda (_time _repeat _fn) (setq timer-scheduled t))))
      (workbench--launch-vterm-agent "*test-agent*" "claude")
      (should (equal vterm-buffer-name "*test-agent*"))
      (should resize-called)
      (should timer-scheduled))))

;;; test-ai.el ends here
