;;; test/unit/test-git.el --- Unit tests for tools/git.el -*- lexical-binding: t; -*-

(require 'test-helper)

;; Stub workbench--project-root before loading the module
(unless (fboundp 'workbench--project-root)
  (defun workbench--project-root () default-directory))

;; Magit stubs
(unless (fboundp 'magit-status)
  (defun magit-status (&optional _dir) nil))
(unless (fboundp 'magit-refresh)
  (defun magit-refresh () nil))

;; Define magit-status-mode as a derived mode for `derived-mode-p' checks
(unless (fboundp 'magit-status-mode)
  (define-derived-mode magit-status-mode special-mode "Magit"))

(workbench-test-load-module "modules/tools/git")

;;; ── Toggle on ──────────────────────────────────────────────────────────────

(ert-deftest popup-magit/toggle-on-stores-config ()
  "Toggling on stores window config in the hash table."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha"))
    (cl-letf (((symbol-function 'delete-other-windows) #'ignore)
              ((symbol-function 'magit-status) (lambda (&rest _) nil)))
      (workbench/toggle-popup-magit)
      (should (gethash "alpha" workbench--popup-magit-configs)))))

(ert-deftest popup-magit/toggle-on-calls-magit-status-when-no-buffer ()
  "When no existing buffer, magit-status is called."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha")
        (magit-called nil))
    (cl-letf (((symbol-function 'delete-other-windows) #'ignore)
              ((symbol-function 'magit-status)
               (lambda (&rest _) (setq magit-called t))))
      (workbench/toggle-popup-magit)
      (should magit-called))))

;;; ── Toggle off ─────────────────────────────────────────────────────────────

(ert-deftest popup-magit/toggle-off-removes-config ()
  "Toggling off removes the workspace entry from the hash table."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha"))
    (puthash "alpha" (current-window-configuration) workbench--popup-magit-configs)
    (workbench/toggle-popup-magit)
    (should-not (gethash "alpha" workbench--popup-magit-configs))))

(ert-deftest popup-magit/toggle-off-restores-layout ()
  "Toggling off calls set-window-configuration with the saved config."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha")
        (restored nil)
        (saved-config (current-window-configuration)))
    (puthash "alpha" saved-config workbench--popup-magit-configs)
    (cl-letf (((symbol-function 'set-window-configuration)
               (lambda (c) (setq restored c))))
      (workbench/toggle-popup-magit)
      (should (eq restored saved-config)))))

;;; ── Buffer tracking per workspace ───────────────────────────────────────────

(ert-deftest popup-magit/buffer-tracked-per-workspace ()
  "After toggle-on, the magit buffer is stored in the buffers hash table."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal))
        (workbench-test--current-workspace "my-project")
        (fake-buf (get-buffer-create "*test-magit-tracking*")))
    (unwind-protect
        (cl-letf (((symbol-function 'delete-other-windows) #'ignore)
                  ((symbol-function 'magit-status)
                   (lambda (&rest _) (set-buffer fake-buf))))
          (workbench/toggle-popup-magit)
          (should (eq (gethash "my-project" workbench--popup-magit-buffers) fake-buf)))
      (kill-buffer fake-buf))))

(ert-deftest popup-magit/different-workspaces-track-different-buffers ()
  "Different workspaces store independent buffers in the hash table."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal))
        (workbench-test--current-workspace "ws-one")
        (buf-one (get-buffer-create "*test-magit-ws-one*"))
        (buf-two (get-buffer-create "*test-magit-ws-two*")))
    (unwind-protect
        (cl-letf (((symbol-function 'delete-other-windows) #'ignore)
                  ((symbol-function 'magit-status)
                   (lambda (&rest _) (set-buffer buf-one))))
          (workbench/toggle-popup-magit)
          (should (eq (gethash "ws-one" workbench--popup-magit-buffers) buf-one))
          ;; Switch workspace
          (let ((workbench-test--current-workspace "ws-two"))
            (cl-letf (((symbol-function 'magit-status)
                       (lambda (&rest _) (set-buffer buf-two))))
              (workbench/toggle-popup-magit)
              (should (eq (gethash "ws-two" workbench--popup-magit-buffers) buf-two))
              (should (eq (gethash "ws-one" workbench--popup-magit-buffers) buf-one)))))
      (kill-buffer buf-one)
      (kill-buffer buf-two))))

;;; ── Stale state clearing ───────────────────────────────────────────────────

(ert-deftest popup-magit/clear-stale-removes-orphaned-entry ()
  "Clear-stale removes config entry when magit buffer is dead (full cleanup)."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha"))
    ;; Entry exists but the buffer is DEAD (killed)
    (let ((buf (get-buffer-create "*stale-buf*")))
      (kill-buffer buf))
    (puthash "alpha" (current-window-configuration) workbench--popup-magit-configs)
    (puthash "alpha" (get-buffer-create "*already-dead*") workbench--popup-magit-buffers)
    ;; Kill the buffer to simulate dead magit buffer
    (kill-buffer "*already-dead*")
    (workbench--popup-magit-clear-stale)
    ;; Full cleanup: both hashes cleared
    (should-not (gethash "alpha" workbench--popup-magit-configs))
    (should-not (gethash "alpha" workbench--popup-magit-buffers))))

(ert-deftest popup-magit/clear-stale-keeps-active-entry ()
  "Clear-stale preserves hash entry when magit-status buffer is displayed."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha")
        (buf (get-buffer-create "*workbench-magit:alpha*")))
    (unwind-protect
        (progn
          ;; Set buffer to magit-status-mode
          (with-current-buffer buf
            (magit-status-mode))
          (puthash "alpha" (current-window-configuration) workbench--popup-magit-configs)
          (puthash "alpha" buf workbench--popup-magit-buffers)
          ;; Display the magit buffer in a window
          (set-window-buffer (selected-window) buf)
          (workbench--popup-magit-clear-stale)
          (should (gethash "alpha" workbench--popup-magit-configs))
          (should (gethash "alpha" workbench--popup-magit-buffers)))
      (kill-buffer buf))))

(ert-deftest popup-magit/clear-stale-no-entry-is-noop ()
  "Clear-stale does nothing when there's no entry for the current workspace."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha"))
    (workbench--popup-magit-clear-stale)
    (should (= 0 (hash-table-count workbench--popup-magit-configs)))
    (should (= 0 (hash-table-count workbench--popup-magit-buffers)))))

;;; ── Frame deletion cleanup ─────────────────────────────────────────────────

(ert-deftest popup-magit/clear-frame-removes-matching-entries ()
  "Clear-frame removes entries whose config belongs to the given frame."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal))
        (frame (selected-frame))
        (buf-a (get-buffer-create "*test-frame-a*"))
        (buf-b (get-buffer-create "*test-frame-b*")))
    (unwind-protect
        (progn
          (puthash "ws-a" (current-window-configuration) workbench--popup-magit-configs)
          (puthash "ws-b" (current-window-configuration) workbench--popup-magit-configs)
          (puthash "ws-a" buf-a workbench--popup-magit-buffers)
          (puthash "ws-b" buf-b workbench--popup-magit-buffers)
          (workbench--popup-magit-clear-frame frame)
          (should (= 0 (hash-table-count workbench--popup-magit-configs)))
          (should (= 0 (hash-table-count workbench--popup-magit-buffers))))
      (kill-buffer buf-a)
      (kill-buffer buf-b))))

(ert-deftest popup-magit/clear-frame-preserves-other-frame-entries ()
  "Clear-frame only removes entries for the specified frame."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal)))
    (puthash "ws-a" (current-window-configuration) workbench--popup-magit-configs)
    (puthash "ws-a" (get-buffer-create "*test-frame-other-a*") workbench--popup-magit-buffers)
    ;; Non-config value simulates entry from another frame
    (puthash "ws-other" 'not-a-config workbench--popup-magit-configs)
    (puthash "ws-other" (get-buffer-create "*test-frame-other-b*") workbench--popup-magit-buffers)
    (workbench--popup-magit-clear-frame (selected-frame))
    (should-not (gethash "ws-a" workbench--popup-magit-configs))
    (should-not (gethash "ws-a" workbench--popup-magit-buffers))
    (should (gethash "ws-other" workbench--popup-magit-configs))
    (should (gethash "ws-other" workbench--popup-magit-buffers))
    (ignore-errors (kill-buffer "*test-frame-other-a*"))
    (ignore-errors (kill-buffer "*test-frame-other-b*"))))

;;; ── Showing predicate ──────────────────────────────────────────────────────

(ert-deftest popup-magit/showing-p-true-when-magit-buffer-visible ()
  "showing-p returns non-nil when a magit-status-mode buffer is in a window."
  (let ((buf (get-buffer-create "*workbench-magit:test*")))
    (unwind-protect
        (progn
          (with-current-buffer buf
            (magit-status-mode))
          (set-window-buffer (selected-window) buf)
          (should (workbench--popup-magit-showing-p)))
      (kill-buffer buf))))

(ert-deftest popup-magit/showing-p-false-when-no-magit-buffer ()
  "showing-p returns nil when no magit-status-mode buffer is displayed."
  ;; The *scratch* buffer (or whatever is current) is not magit-status-mode
  (should-not (workbench--popup-magit-showing-p)))

;;; ── Buffer reuse on re-toggle ──────────────────────────────────────────────

(ert-deftest popup-magit/toggle-on-reuses-existing-buffer ()
  "Toggling on when buffer exists reuses it and calls magit-refresh."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal))
        (workbench-test--current-workspace "alpha")
        (refreshed nil)
        (buf (get-buffer-create "*workbench-magit:alpha*")))
    (unwind-protect
        (progn
          (with-current-buffer buf
            (magit-status-mode))
          ;; Pre-store the buffer as if a previous toggle created it
          (puthash "alpha" buf workbench--popup-magit-buffers)
          (cl-letf (((symbol-function 'delete-other-windows) #'ignore)
                    ((symbol-function 'magit-refresh)
                     (lambda () (setq refreshed t))))
            (workbench/toggle-popup-magit)
            (should refreshed)
            (should (eq (gethash "alpha" workbench--popup-magit-buffers) buf))))
      (kill-buffer buf))))

;;; ── Cross-workspace isolation ──────────────────────────────────────────────

(ert-deftest popup-magit/cross-workspace-isolation ()
  "Popup state in workspace A is independent of workspace B."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal))
        (workbench-test--current-workspace "ws-A"))
    (cl-letf (((symbol-function 'delete-other-windows) #'ignore)
              ((symbol-function 'magit-status) (lambda (&rest _) nil)))
      ;; Toggle on in ws-A
      (workbench/toggle-popup-magit)
      (should (gethash "ws-A" workbench--popup-magit-configs))
      ;; Switch to ws-B — ws-B should have no state
      (let ((workbench-test--current-workspace "ws-B"))
        (should-not (gethash "ws-B" workbench--popup-magit-configs))
        ;; Toggle on in ws-B
        (workbench/toggle-popup-magit)
        (should (gethash "ws-B" workbench--popup-magit-configs))
        ;; ws-A state still intact
        (should (gethash "ws-A" workbench--popup-magit-configs))))))

(ert-deftest popup-magit/toggling-off-in-one-ws-preserves-other ()
  "Toggling off in ws-A does not affect ws-B state."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal))
        (workbench-test--current-workspace "ws-A"))
    (puthash "ws-A" (current-window-configuration) workbench--popup-magit-configs)
    (puthash "ws-B" (current-window-configuration) workbench--popup-magit-configs)
    (workbench/toggle-popup-magit)
    ;; ws-A cleared, ws-B still present
    (should-not (gethash "ws-A" workbench--popup-magit-configs))
    (should (gethash "ws-B" workbench--popup-magit-configs))))

;;; ── Regression tests ────────────────────────────────────────────────────────

(ert-deftest popup-magit/regression-clear-stale-while-visible-breaks-toggle ()
  "FIXED: toggle now checks showing-p OR hash entry to decide hide vs show."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal))
        (workbench-test--current-workspace "test")
        (magit-called nil))
    ;; Magit IS showing (window has magit buffer)
    (cl-letf (((symbol-function 'workbench--popup-magit-showing-p) (lambda () t))
              ((symbol-function 'magit-status) (lambda (&rest _) (setq magit-called t)))
              ((symbol-function 'magit-refresh) #'ignore)
              ((symbol-function 'delete-other-windows) #'ignore)
              ((symbol-function 'switch-to-buffer) #'ignore)
              ((symbol-function 'workbench--project-root) (lambda () "/tmp/")))
      ;; Hash entry was cleared by clear-stale (persp hook timing)
      ;; but magit is still visible
      (should-not (gethash "test" workbench--popup-magit-configs))
      ;; Toggle should HIDE magit (it's visible), not show it
      (workbench/toggle-popup-magit)
      ;; It SHOULD detect magit is visible and hide it
      (should-not magit-called))))

(ert-deftest popup-magit/regression-toggle-on-does-not-overwrite-when-showing ()
  "FIXED: When magit is showing and hash entry exists, toggle hides (doesn't overwrite)."
  (let ((workbench--popup-magit-configs (make-hash-table :test 'equal))
        (workbench--popup-magit-buffers (make-hash-table :test 'equal))
        (workbench-test--current-workspace "test")
        (sentinel (current-window-configuration))
        (magit-called nil))
    (puthash "test" sentinel workbench--popup-magit-configs)
    (cl-letf (((symbol-function 'workbench--popup-magit-showing-p) (lambda () t))
              ((symbol-function 'magit-status) (lambda (&rest _) (setq magit-called t)))
              ((symbol-function 'workbench--popup-magit-buffer) (lambda () nil))
              ((symbol-function 'bury-buffer) #'ignore))
      ;; Magit is showing + hash entry exists → should HIDE, not show
      (workbench/toggle-popup-magit)
      ;; Entry removed (hidden)
      (should-not (gethash "test" workbench--popup-magit-configs))
      ;; magit-status was NOT called (didn't try to show)
      (should-not magit-called))))

(ert-deftest popup-magit/regression-note-showing-p-requires-magit-loaded ()
  "showing-p depends on magit-status-mode being defined.
Without magit loaded, it always returns nil. In test-git.el we stub
magit-status-mode, so this documents the design note: the hash-entry
check is the primary toggle condition, showing-p is a fallback."
  ;; With magit-status-mode defined (stubbed above), showing-p returns nil
  ;; when no magit buffer is displayed — confirming it's a secondary check.
  (should-not (workbench--popup-magit-showing-p)))

(provide 'test-git)
;;; test/unit/test-git.el ends here
