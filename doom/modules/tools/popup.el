;;; tools/popup.el -*- lexical-binding: t; -*-

;; Shared popup infrastructure for workspace-scoped full-frame toggles.
;; Used by terminals.el (popup terminal) and git.el (popup magit).
;;
;; A popup takes over the frame, saving the current window configuration.
;; On dismiss, the saved configuration is restored and the primary editing
;; window is selected. Each workspace maintains independent state.
;;
;; API is function-based with explicit hash table arguments so consumers
;; keep their own state variables (preserving existing test interfaces).

(require 'seq)

(declare-function +workspace-current-name "doom-modules")

;;; ── Primary Window Selection ───────────────────────────────────────────────

(defun workbench-popup-primary-window ()
  "Return the best window to return focus to after dismissing a popup.
Prefers a window showing a file-visiting or code buffer."
  (or (seq-find (lambda (win)
                  (let ((buf (window-buffer win)))
                    (and (not (window-dedicated-p win))
                         (not (minibufferp buf))
                         (with-current-buffer buf
                           (and (not (derived-mode-p 'vterm-mode))
                                (not (string-prefix-p "*project-" (buffer-name)))
                                (not (string-prefix-p " *Treemacs" (buffer-name)))
                                (not (string-prefix-p "*workbench-popup-term" (buffer-name))))))))
                (window-list))
      (selected-window)))

;;; ── Hide (restore layout) ──────────────────────────────────────────────────

(defun workbench-popup-hide (configs &optional buffer-to-bury)
  "Hide a popup: restore saved layout from CONFIGS hash table.
Optionally buries BUFFER-TO-BURY if the config is stale.
Selects the primary editing window after restoration."
  (let* ((ws (+workspace-current-name))
         (config (gethash ws configs)))
    (remhash ws configs)
    (if (and (window-configuration-p config)
             (eq (window-configuration-frame config) (selected-frame)))
        (progn
          (set-window-configuration config)
          ;; Guard against stale configs referencing killed buffers
          (unless (buffer-live-p (window-buffer))
            (switch-to-buffer (other-buffer)))
          (select-window (workbench-popup-primary-window)))
      ;; Config is stale — bury and select primary
      (when (and buffer-to-bury (buffer-live-p buffer-to-bury))
        (bury-buffer buffer-to-bury))
      (select-window (workbench-popup-primary-window)))))

;;; ── Show (prepare frame) ───────────────────────────────────────────────────

(defun workbench-popup-show-prepare (configs)
  "Prepare the frame for showing a popup: save layout into CONFIGS, clear windows.
Handles dedicated windows safely. Returns non-nil on success."
  (let ((ws (+workspace-current-name)))
    ;; Escape dedicated windows
    (when (window-dedicated-p)
      (let ((target (seq-find (lambda (w) (not (window-dedicated-p w)))
                              (window-list))))
        (if target
            (select-window target)
          (set-window-dedicated-p (selected-window) nil))))
    ;; Save current layout
    (unless (gethash ws configs)
      (puthash ws (current-window-configuration) configs))
    ;; Take over frame
    (let ((ignore-window-parameters t))
      (delete-other-windows))
    (set-window-dedicated-p (selected-window) nil)
    t))

;;; ── Cleanup Hooks ──────────────────────────────────────────────────────────

(defun workbench-popup-clear-stale (configs buffers showing-p-fn)
  "Discard stale popup state from CONFIGS/BUFFERS when popup is not visible.
SHOWING-P-FN should return non-nil if the popup is currently displayed.
Call from `persp-activated-functions'."
  (let ((ws (+workspace-current-name)))
    (when (and (gethash ws configs)
               (not (funcall showing-p-fn)))
      (let ((buf (gethash ws buffers)))
        (if (and buf (buffer-live-p buf))
            ;; Buffer alive but not visible — clear config only
            (remhash ws configs)
          ;; Buffer dead — full cleanup
          (remhash ws configs)
          (remhash ws buffers))))))

(defun workbench-popup-clear-frame (configs buffers frame)
  "Remove entries from CONFIGS/BUFFERS whose saved config belongs to FRAME.
Call from `delete-frame-functions'."
  (let ((stale-keys nil))
    (maphash (lambda (ws config)
               (when (and (window-configuration-p config)
                          (eq (window-configuration-frame config) frame))
                 (push ws stale-keys)))
             configs)
    (dolist (ws stale-keys)
      (remhash ws configs)
      (remhash ws buffers))))

(provide 'workbench-popup)
;;; tools/popup.el ends here
