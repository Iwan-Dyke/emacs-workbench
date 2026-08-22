;;; test/unit/test-terminals.el --- Unit tests for tools/terminals.el -*- lexical-binding: t; -*-

(require 'test-helper)

;; Stub workbench--project-root before loading the module
(unless (fboundp 'workbench--project-root)
  (defun workbench--project-root () default-directory))

(workbench-test-load-module "modules/tools/terminals")

;;; ── Buffer naming ──────────────────────────────────────────────────────────

(ert-deftest popup-terminal/buffer-name-includes-workspace ()
  "Buffer name includes the current workspace name."
  (let ((workbench-test--current-workspace "project-a"))
    (should (equal (workbench--popup-terminal-buffer-name)
                   "*workbench-popup-term:project-a*"))))

(ert-deftest popup-terminal/different-workspaces-get-different-buffers ()
  "Different workspaces produce different buffer names."
  (let ((workbench-test--current-workspace "ws-one"))
    (let ((name-one (workbench--popup-terminal-buffer-name)))
      (let ((workbench-test--current-workspace "ws-two"))
        (should-not (equal name-one (workbench--popup-terminal-buffer-name)))))))

(ert-deftest popup-terminal/buffer-name-with-spaces-in-workspace ()
  "Workspace names can contain spaces — buffer name should still work."
  (let ((workbench-test--current-workspace "my project"))
    (should (equal (workbench--popup-terminal-buffer-name)
                   "*workbench-popup-term:my project*"))))

(ert-deftest popup-terminal/buffer-name-with-special-chars ()
  "Workspace names with special chars shouldn't break buffer lookup."
  (let ((workbench-test--current-workspace "feat/DPT-42"))
    (should (equal (workbench--popup-terminal-buffer-name)
                   "*workbench-popup-term:feat/DPT-42*"))))

;;; ── Toggle on (show) ───────────────────────────────────────────────────────

(ert-deftest popup-terminal/toggle-on-stores-config ()
  "Toggling on stores window config in the hash table."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha"))
    (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p) (lambda () nil))
              ((symbol-function 'delete-other-windows) #'ignore)
              ((symbol-function 'workbench--popup-terminal-buffer)
               (lambda () (get-buffer-create "*workbench-popup-term:alpha*"))))
      (workbench/toggle-popup-terminal)
      (should (gethash "alpha" workbench--popup-terminal-configs))
      (kill-buffer "*workbench-popup-term:alpha*"))))

(ert-deftest popup-terminal/toggle-on-creates-buffer ()
  "Toggling on creates the workspace-named buffer."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha"))
    (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p) (lambda () nil))
              ((symbol-function 'delete-other-windows) #'ignore)
              ((symbol-function 'workbench--popup-terminal-buffer)
               (lambda () (get-buffer-create "*workbench-popup-term:alpha*"))))
      (workbench/toggle-popup-terminal)
      (should (get-buffer "*workbench-popup-term:alpha*"))
      (kill-buffer "*workbench-popup-term:alpha*"))))

(ert-deftest popup-terminal/toggle-on-reuses-existing-buffer ()
  "Toggling on a second time reuses the same buffer, not a new one."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha")
        (buf (get-buffer-create "*workbench-popup-term:alpha*")))
    (unwind-protect
        (progn
          ;; Mark buffer as having vterm-mode
          (with-current-buffer buf
            (setq major-mode 'vterm-mode))
          (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p) (lambda () nil))
                    ((symbol-function 'delete-other-windows) #'ignore)
                    ((symbol-function 'derived-mode-p)
                     (lambda (&rest modes) (memq major-mode modes))))
            (workbench/toggle-popup-terminal)
            ;; Should still be the same buffer object
            (should (eq (get-buffer "*workbench-popup-term:alpha*") buf))))
      (kill-buffer buf))))

(ert-deftest popup-terminal/toggle-with-stale-entry-takes-hide-branch ()
  "If hash entry exists but popup isn't showing, toggle treats it as hide.
The stale entry is removed so next toggle will cleanly show."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "test"))
    (let ((buf (get-buffer-create "*workbench-popup-term:test*"))
          (sentinel-value 'i-am-a-stale-config))
      (unwind-protect
          (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p) (lambda () nil))
                    ((symbol-function 'workbench--popup-terminal-buffer) (lambda () buf))
                    ((symbol-function 'delete-other-windows) #'ignore)
                    ((symbol-function 'switch-to-buffer) #'ignore))
            ;; Pre-existing entry (stale — popup not actually visible)
            (puthash "test" sentinel-value workbench--popup-terminal-configs)
            ;; Toggle detects stale entry via or-condition and takes hide branch
            (workbench/toggle-popup-terminal)
            ;; Entry is removed (cleaned up)
            (should-not (gethash "test" workbench--popup-terminal-configs)))
        (kill-buffer buf)))))

(ert-deftest popup-terminal/double-toggle-on-clears-stale-entry ()
  "If showing-p returns nil but a hash entry exists, the second toggle
takes the hide branch and clears the entry (not the show branch)."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "test"))
    (let ((buf (get-buffer-create "*workbench-popup-term:test*")))
      (unwind-protect
          (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p) (lambda () nil))
                    ((symbol-function 'workbench--popup-terminal-buffer) (lambda () buf))
                    ((symbol-function 'delete-other-windows) #'ignore)
                    ((symbol-function 'switch-to-buffer) #'ignore))
            ;; First toggle-on: saves config and shows popup
            (workbench/toggle-popup-terminal)
            (let ((first-config (gethash "test" workbench--popup-terminal-configs)))
              (should first-config)
              ;; Second toggle with showing-p still nil (simulating stale state):
              ;; the or-condition detects the hash entry and takes hide branch
              (workbench/toggle-popup-terminal)
              ;; Entry is cleared (hide branch remhashes it)
              (should-not (gethash "test" workbench--popup-terminal-configs))))
        (kill-buffer buf)))))

;;; ── Toggle off (hide) ──────────────────────────────────────────────────────

(ert-deftest popup-terminal/toggle-off-removes-config ()
  "Toggling off removes the workspace entry from the hash table."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha"))
    ;; Pre-populate as if the popup is active
    (puthash "alpha" (current-window-configuration) workbench--popup-terminal-configs)
    (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p) (lambda () t)))
      (workbench/toggle-popup-terminal)
      (should-not (gethash "alpha" workbench--popup-terminal-configs)))))

(ert-deftest popup-terminal/toggle-off-restores-layout ()
  "Toggling off calls set-window-configuration with the saved config."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha")
        (restored nil)
        (saved-config (current-window-configuration)))
    (puthash "alpha" saved-config workbench--popup-terminal-configs)
    (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p) (lambda () t))
              ((symbol-function 'set-window-configuration)
               (lambda (c) (setq restored c))))
      (workbench/toggle-popup-terminal)
      (should (eq restored saved-config)))))

(ert-deftest popup-terminal/toggle-off-with-nil-config-buries-buffer ()
  "If hash entry is nil (cleared by stale check), toggle-off falls through
to bury-buffer path."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "test")
        (buried nil))
    (let ((buf (get-buffer-create "*workbench-popup-term:test*")))
      (unwind-protect
          (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p) (lambda () t))
                    ((symbol-function 'bury-buffer) (lambda (&optional _) (setq buried t)))
                    ((symbol-function 'other-buffer) (lambda (&rest _) (current-buffer)))
                    ((symbol-function 'switch-to-buffer) #'ignore))
            (workbench/toggle-popup-terminal)
            ;; Should have attempted to bury
            (should buried))
        (kill-buffer buf)))))

(ert-deftest popup-terminal/toggle-off-config-from-different-frame-buries ()
  "If saved config belongs to a frame that no longer exists, falls through
to bury-buffer path instead of crashing."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "test")
        (buried nil))
    ;; Store a non-window-configuration value (simulating stale frame reference)
    (puthash "test" 'not-a-window-config workbench--popup-terminal-configs)
    (let ((buf (get-buffer-create "*workbench-popup-term:test*")))
      (unwind-protect
          (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p) (lambda () t))
                    ((symbol-function 'bury-buffer) (lambda (&optional _) (setq buried t)))
                    ((symbol-function 'other-buffer) (lambda (&rest _) (current-buffer)))
                    ((symbol-function 'switch-to-buffer) #'ignore))
            (workbench/toggle-popup-terminal)
            ;; Config removed from hash
            (should-not (gethash "test" workbench--popup-terminal-configs))
            ;; Bury path taken
            (should buried))
        (kill-buffer buf)))))

;;; ── Stale state clearing ───────────────────────────────────────────────────

(ert-deftest popup-terminal/clear-stale-removes-orphaned-entry ()
  "Clear-stale removes hash entry when popup buffer is not visible."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha"))
    ;; Entry exists but no buffer is visible (simulating persp overwrite)
    (puthash "alpha" (current-window-configuration) workbench--popup-terminal-configs)
    (workbench--popup-terminal-clear-stale)
    (should-not (gethash "alpha" workbench--popup-terminal-configs))))

(ert-deftest popup-terminal/clear-stale-keeps-active-entry ()
  "Clear-stale preserves hash entry when popup buffer is actually displayed."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha")
        (buf (get-buffer-create "*workbench-popup-term:alpha*")))
    (unwind-protect
        (progn
          (puthash "alpha" (current-window-configuration) workbench--popup-terminal-configs)
          ;; Display the buffer in a window so get-buffer-window returns non-nil
          (set-window-buffer (selected-window) buf)
          (workbench--popup-terminal-clear-stale)
          (should (gethash "alpha" workbench--popup-terminal-configs)))
      (kill-buffer buf))))

(ert-deftest popup-terminal/clear-stale-no-entry-is-noop ()
  "Clear-stale does nothing when there's no entry for the current workspace."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha"))
    ;; No entry exists — should not error
    (workbench--popup-terminal-clear-stale)
    (should (= 0 (hash-table-count workbench--popup-terminal-configs)))))

(ert-deftest popup-terminal/clear-stale-when-buffer-killed ()
  "If the popup buffer was killed (vterm exited), stale check should clear the entry."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "test"))
    (puthash "test" (current-window-configuration) workbench--popup-terminal-configs)
    ;; Buffer doesn't exist at all
    (should-not (get-buffer "*workbench-popup-term:test*"))
    (workbench--popup-terminal-clear-stale)
    ;; Entry should be cleared
    (should-not (gethash "test" workbench--popup-terminal-configs))))

(ert-deftest popup-terminal/clear-stale-buffer-exists-but-not-in-window ()
  "Buffer is live but not displayed in any window — entry should be cleared."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "test"))
    (puthash "test" (current-window-configuration) workbench--popup-terminal-configs)
    (let ((buf (get-buffer-create "*workbench-popup-term:test*")))
      (unwind-protect
          (progn
            ;; Buffer exists but not in any window (bury it)
            (bury-buffer buf)
            (workbench--popup-terminal-clear-stale)
            (should-not (gethash "test" workbench--popup-terminal-configs)))
        (kill-buffer buf)))))

(ert-deftest popup-terminal/clear-stale-preserves-when-buffer-in-window ()
  "If popup buffer IS visible in a window, entry should be preserved."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "test"))
    (puthash "test" (current-window-configuration) workbench--popup-terminal-configs)
    (let ((buf (get-buffer-create "*workbench-popup-term:test*")))
      (unwind-protect
          (progn
            ;; Display buffer in current window
            (set-window-buffer (selected-window) buf)
            (workbench--popup-terminal-clear-stale)
            ;; Entry preserved because buffer is visible
            (should (gethash "test" workbench--popup-terminal-configs)))
        (kill-buffer buf)))))

;;; ── Frame cleanup ──────────────────────────────────────────────────────────

(ert-deftest popup-terminal/clear-frame-removes-matching-entries ()
  "Clear-frame removes entries whose config belongs to the given frame."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (frame (selected-frame)))
    ;; current-window-configuration belongs to selected-frame
    (puthash "ws-a" (current-window-configuration) workbench--popup-terminal-configs)
    (puthash "ws-b" (current-window-configuration) workbench--popup-terminal-configs)
    (workbench--popup-terminal-clear-frame frame)
    (should (= 0 (hash-table-count workbench--popup-terminal-configs)))))

(ert-deftest popup-terminal/clear-frame-preserves-other-frame-entries ()
  "Clear-frame only removes entries for the specified frame."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal)))
    ;; Store a real config (belongs to selected-frame)
    (puthash "ws-a" (current-window-configuration) workbench--popup-terminal-configs)
    ;; Store a non-window-configuration value to simulate another frame's entry
    ;; (clear-frame checks window-configuration-p first)
    (puthash "ws-other" 'not-a-config workbench--popup-terminal-configs)
    (workbench--popup-terminal-clear-frame (selected-frame))
    ;; ws-a removed, ws-other preserved (it's not a window-configuration)
    (should-not (gethash "ws-a" workbench--popup-terminal-configs))
    (should (gethash "ws-other" workbench--popup-terminal-configs))))

;;; ── Cross-workspace isolation ──────────────────────────────────────────────

(ert-deftest popup-terminal/cross-workspace-state-is-independent ()
  "Popup state in workspace A is independent of workspace B."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "ws-A"))
    (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p) (lambda () nil))
              ((symbol-function 'delete-other-windows) #'ignore)
              ((symbol-function 'workbench--popup-terminal-buffer)
               (lambda () (get-buffer-create (workbench--popup-terminal-buffer-name)))))
      ;; Toggle on in ws-A
      (workbench/toggle-popup-terminal)
      (should (gethash "ws-A" workbench--popup-terminal-configs))
      ;; Switch to ws-B — ws-B should have no state
      (let ((workbench-test--current-workspace "ws-B"))
        (should-not (gethash "ws-B" workbench--popup-terminal-configs))
        ;; Toggle on in ws-B
        (workbench/toggle-popup-terminal)
        (should (gethash "ws-B" workbench--popup-terminal-configs))
        ;; ws-A state still intact
        (should (gethash "ws-A" workbench--popup-terminal-configs))
        (kill-buffer "*workbench-popup-term:ws-B*")))
    (kill-buffer "*workbench-popup-term:ws-A*")))

(ert-deftest popup-terminal/toggling-off-in-one-ws-preserves-other ()
  "Toggling off in ws-A does not affect ws-B state."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "ws-A"))
    ;; Both workspaces have active popups
    (puthash "ws-A" (current-window-configuration) workbench--popup-terminal-configs)
    (puthash "ws-B" (current-window-configuration) workbench--popup-terminal-configs)
    (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p) (lambda () t)))
      (workbench/toggle-popup-terminal)
      ;; ws-A cleared, ws-B still present
      (should-not (gethash "ws-A" workbench--popup-terminal-configs))
      (should (gethash "ws-B" workbench--popup-terminal-configs)))))

;;; ── Dead buffer handling ───────────────────────────────────────────────────

(ert-deftest popup-terminal/dead-buffer-not-in-vterm-mode-gets-recreated ()
  "If buffer exists but isn't in vterm-mode, it's killed and a fresh one created."
  (let ((workbench-test--current-workspace "test"))
    (cl-letf (((symbol-function 'workbench--project-root) (lambda () "/tmp/")))
      (let ((buf (get-buffer-create "*workbench-popup-term:test*")))
        (unwind-protect
            (progn
              ;; Buffer exists in fundamental-mode (simulating dead vterm)
              (with-current-buffer buf
                (should-not (derived-mode-p 'vterm-mode)))
              ;; popup-terminal-buffer should kill the old and return a fresh buffer
              (let ((result (workbench--popup-terminal-buffer)))
                ;; Old buffer was killed, new one created with same name
                (should-not (eq result buf))
                (should (buffer-live-p result))
                (should (equal (buffer-name result) "*workbench-popup-term:test*"))
                ;; directory is set correctly
                (with-current-buffer result
                  (should (equal default-directory "/tmp/")))
                (kill-buffer result)))
          ;; Cleanup (in case test fails early)
          (when (get-buffer "*workbench-popup-term:test*")
            (kill-buffer "*workbench-popup-term:test*")))))))

(ert-deftest popup-terminal/killed-buffer-creates-fresh ()
  "After buffer is killed, next toggle creates a fresh one."
  (let ((workbench-test--current-workspace "test"))
    (cl-letf (((symbol-function 'workbench--project-root) (lambda () "/tmp/")))
      ;; Create and kill
      (let ((buf (get-buffer-create "*workbench-popup-term:test*")))
        (kill-buffer buf))
      ;; Now get-buffer returns nil, so popup-terminal-buffer creates fresh
      (let ((result (workbench--popup-terminal-buffer)))
        (unwind-protect
            (progn
              (should (buffer-live-p result))
              (should (equal (buffer-name result) "*workbench-popup-term:test*")))
          (kill-buffer result))))))

(ert-deftest popup-terminal/toggle-after-vterm-error-clears-stale-entry ()
  "When vterm-mode errors, toggle restores saved layout and clears hash entry.
The condition-case inside the show branch handles the error: it restores the
saved window config and signals user-error so the user sees a clean message."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "test")
        (vterm-mode-calls 0)
        (config-restored nil))
    (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p) (lambda () nil))
              ((symbol-function 'workbench--project-root) (lambda () "/tmp/"))
              ((symbol-function 'delete-other-windows) #'ignore)
              ((symbol-function 'switch-to-buffer) #'ignore)
              ((symbol-function 'set-window-configuration)
               (lambda (_c) (setq config-restored t)))
              ;; vterm-mode fails (simulating missing libvterm)
              ((symbol-function 'vterm-mode)
               (lambda () (cl-incf vterm-mode-calls) (error "vterm needs libvterm"))))
      ;; Toggle attempt — vterm-mode errors, condition-case catches it
      (condition-case nil
          (workbench/toggle-popup-terminal)
        (user-error nil))
      ;; vterm-mode was called once
      (should (= vterm-mode-calls 1))
      ;; Hash entry was cleared by the error handler (restored config)
      (should-not (gethash "test" workbench--popup-terminal-configs))
      ;; Window config was restored
      (should config-restored))
    ;; Cleanup
    (when (get-buffer "*workbench-popup-term:test*")
      (kill-buffer "*workbench-popup-term:test*"))))

;;; ── Edge cases (showing-p, rapid toggle, special chars) ────────────────────

(ert-deftest popup-terminal/showing-p-false-when-popup-not-in-window ()
  "showing-p returns nil when popup buffer exists but is not displayed."
  (let ((workbench-test--current-workspace "test"))
    (let ((buf (get-buffer-create "*workbench-popup-term:test*")))
      (unwind-protect
          (progn
            ;; Popup buffer exists and is live, but we're in a different buffer
            (with-current-buffer (get-buffer-create "*other*")
              ;; showing-p should be nil because popup is not in any window
              (should-not (workbench--popup-terminal-showing-p))))
        (kill-buffer buf)
        (when (get-buffer "*other*") (kill-buffer "*other*"))))))

(ert-deftest popup-terminal/showing-p-true-when-popup-in-window ()
  "showing-p returns t when popup buffer is visible in a window."
  (let ((workbench-test--current-workspace "test"))
    (let ((buf (get-buffer-create "*workbench-popup-term:test*")))
      (unwind-protect
          (progn
            (set-window-buffer (selected-window) buf)
            (should (workbench--popup-terminal-showing-p)))
        (kill-buffer buf)))))

(ert-deftest popup-terminal/showing-p-detects-visible-popup-from-other-buffer ()
  "showing-p detects popup in window even when current-buffer is different."
  (let ((workbench-test--current-workspace "test"))
    (let ((buf (get-buffer-create "*workbench-popup-term:test*")))
      (unwind-protect
          (progn
            ;; Display the popup buffer in the current window
            (set-window-buffer (selected-window) buf)
            ;; But switch current-buffer to something else (simulating focus move)
            (with-current-buffer (get-buffer-create "*other*")
              ;; showing-p SHOULD return t because the popup is visible in a window
              (should (workbench--popup-terminal-showing-p))))
        (kill-buffer buf)
        (when (get-buffer "*other*") (kill-buffer "*other*"))))))

(ert-deftest popup-terminal/rapid-toggle-on-off-restores-clean-state ()
  "Toggle on then immediately off should leave no hash entry."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "test")
        (showing nil))
    (let ((buf (get-buffer-create "*workbench-popup-term:test*")))
      (unwind-protect
          (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p)
                     (lambda () showing))
                    ((symbol-function 'workbench--popup-terminal-buffer)
                     (lambda () buf))
                    ((symbol-function 'delete-other-windows) #'ignore)
                    ((symbol-function 'switch-to-buffer) #'ignore))
            ;; Toggle on
            (workbench/toggle-popup-terminal)
            (should (gethash "test" workbench--popup-terminal-configs))
            ;; Now popup is "showing"
            (setq showing t)
            ;; Toggle off
            (workbench/toggle-popup-terminal)
            (should-not (gethash "test" workbench--popup-terminal-configs)))
        (kill-buffer buf)))))

(ert-deftest popup-terminal/toggle-with-stale-hash-clears-entry ()
  "If hash entry exists from a stale state, toggle takes hide branch and clears it."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "test")
        (original-config 'original-saved-config))
    ;; Simulate: a previous toggle saved config
    (puthash "test" original-config workbench--popup-terminal-configs)
    (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p) (lambda () nil))
              ((symbol-function 'workbench--popup-terminal-buffer)
               (lambda () (get-buffer-create "*test-term*")))
              ((symbol-function 'delete-other-windows) #'ignore)
              ((symbol-function 'switch-to-buffer) #'ignore))
      (workbench/toggle-popup-terminal)
      ;; The or-condition detects the hash entry and takes hide branch
      (should-not (gethash "test" workbench--popup-terminal-configs))
      (when (get-buffer "*test-term*") (kill-buffer "*test-term*")))))

;;; ── Regression tests ────────────────────────────────────────────────────────

(ert-deftest popup-terminal/regression-open-terminal-workspace-uses-project-root ()
  "FIXED: open-terminal-workspace now uses current project root."
  (let ((default-directory "/tmp/test-project/")
        (vterm-dir nil))
    (cl-letf (((symbol-function '+workspace/new) #'ignore)
              ((symbol-function 'workbench--popup-terminal-sensible-root)
               (lambda () "/tmp/test-project/"))
              ((symbol-function 'vterm)
               (lambda (_name)
                 (setq vterm-dir default-directory)
                 (get-buffer-create "*terminal*"))))
      (workbench/open-terminal-workspace)
      (should (equal vterm-dir "/tmp/test-project/"))
      (when (get-buffer "*terminal*") (kill-buffer "*terminal*")))))

;;; ── Primary window selection ───────────────────────────────────────────────

(ert-deftest popup-terminal/primary-window-prefers-non-dedicated ()
  "Primary window finder skips dedicated windows (e.g. Treemacs)."
  ;; In batch Emacs we only have one window, so we test the function's logic
  ;; by checking it returns the selected window when it's not dedicated
  (let ((win (selected-window)))
    (set-window-dedicated-p win nil)
    (with-current-buffer (get-buffer-create "*test-code*")
      (set-window-buffer win (current-buffer))
      (should (eq (workbench--popup-terminal-primary-window) win)))
    (kill-buffer "*test-code*")))

(ert-deftest popup-terminal/primary-window-skips-vterm-buffers ()
  "Primary window finder skips windows showing vterm buffers (AI panes)."
  (let ((win (selected-window))
        (buf (get-buffer-create "*project-kiro:test*")))
    (unwind-protect
        (progn
          (set-window-buffer win buf)
          (set-window-dedicated-p win nil)
          ;; Since this is the only window, primary-window falls back to selected
          ;; but would not PREFER it. With one window there's no alternative.
          (let ((result (workbench--popup-terminal-primary-window)))
            ;; Should still return a window (fallback)
            (should (window-live-p result))))
      (kill-buffer buf))))

(ert-deftest popup-terminal/primary-window-skips-popup-term-buffers ()
  "Primary window finder skips windows showing the popup terminal itself."
  (let ((win (selected-window))
        (buf (get-buffer-create "*workbench-popup-term:test*")))
    (unwind-protect
        (progn
          (set-window-buffer win buf)
          (set-window-dedicated-p win nil)
          (let ((result (workbench--popup-terminal-primary-window)))
            ;; Falls back to selected window since there's no alternative
            (should (window-live-p result))))
      (kill-buffer buf))))

(ert-deftest popup-terminal/toggle-on-from-dedicated-window-works ()
  "Toggle-on handles dedicated windows (Treemacs) by selecting a non-dedicated
window first, then clearing dedication after delete-other-windows."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "test")
        (delete-called nil)
        (switched-to nil)
        (dedication-cleared nil))
    (let ((buf (get-buffer-create "*workbench-popup-term:test*")))
      (unwind-protect
          (progn
            ;; Mark current window as dedicated (simulating Treemacs)
            (set-window-dedicated-p (selected-window) t)
            (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p) (lambda () nil))
                      ((symbol-function 'delete-other-windows)
                       (lambda () (setq delete-called t)))
                      ((symbol-function 'workbench--popup-terminal-buffer) (lambda () buf))
                      ((symbol-function 'switch-to-buffer)
                       (lambda (b) (setq switched-to b)))
                      ((symbol-function 'set-window-dedicated-p)
                       (lambda (win val)
                         (when (not val) (setq dedication-cleared t)))))
              (workbench/toggle-popup-terminal)
              ;; Should have cleared dedication so switch-to-buffer works
              (should dedication-cleared)
              ;; Should have attempted to show the terminal
              (should (eq switched-to buf))))
        ;; Cleanup
        (set-window-dedicated-p (selected-window) nil)
        (kill-buffer buf)))))

(ert-deftest popup-terminal/toggle-off-selects-primary-window ()
  "After restoring layout, toggle-off selects the primary editing window
rather than landing on whichever window was focused when popup was opened."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal))
        (workbench-test--current-workspace "test")
        (primary-called nil))
    (puthash "test" (current-window-configuration) workbench--popup-terminal-configs)
    (cl-letf (((symbol-function 'workbench--popup-terminal-showing-p) (lambda () t))
              ((symbol-function 'workbench-popup-primary-window)
               (lambda () (setq primary-called t) (selected-window))))
      (workbench/toggle-popup-terminal)
      ;; Should have called primary-window selection after restore
      (should primary-called))))

;;; ── sensible-root fallback chain ───────────────────────────────────────────

(ert-deftest popup-terminal/sensible-root-prefers-project-root ()
  "sensible-root returns project root when it's not ~ or /."
  (cl-letf (((symbol-function 'workbench--project-root)
             (lambda () "/tmp/my-project/")))
    (should (equal (workbench--popup-terminal-sensible-root) "/tmp/my-project/"))))

(ert-deftest popup-terminal/sensible-root-falls-back-to-workspace-directory ()
  "sensible-root uses workspace directory registry when project root is ~/."
  (let ((workbench--workspace-directories (make-hash-table :test 'equal)))
    (puthash "test-ws" "/tmp/ws-dir/" workbench--workspace-directories)
    (cl-letf (((symbol-function 'workbench--project-root)
               (lambda () (expand-file-name "~/")))
              ((symbol-function '+workspace-current-name)
               (lambda () "test-ws")))
      (should (equal (workbench--popup-terminal-sensible-root) "/tmp/ws-dir/")))))

(ert-deftest popup-terminal/sensible-root-falls-back-to-code-root ()
  "sensible-root falls back to workbench-jira-code-root when all else fails."
  (let ((workbench--workspace-directories (make-hash-table :test 'equal))
        (workbench-jira-code-root "~/code/"))
    (cl-letf (((symbol-function 'workbench--project-root)
               (lambda () (expand-file-name "~/")))
              ((symbol-function '+workspace-current-name)
               (lambda () "unknown-ws")))
      (should (equal (workbench--popup-terminal-sensible-root)
                     (expand-file-name "~/code/"))))))

(ert-deftest popup-terminal/sensible-root-rejects-root-directory ()
  "sensible-root does not return / as the project root."
  (let ((workbench--workspace-directories (make-hash-table :test 'equal))
        (workbench-jira-code-root "~/code/"))
    (cl-letf (((symbol-function 'workbench--project-root)
               (lambda () "/"))
              ((symbol-function '+workspace-current-name)
               (lambda () "ws")))
      (should-not (equal (workbench--popup-terminal-sensible-root) "/")))))

(provide 'test-terminals)
;;; test/unit/test-terminals.el ends here
