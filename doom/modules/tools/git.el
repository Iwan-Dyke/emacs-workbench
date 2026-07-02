;;; tools/git.el -*- lexical-binding: t; -*-

(declare-function workbench--project-root "modules/tools/files")
(declare-function magit-status "magit-status")
(declare-function magit-refresh "magit-mode")
(declare-function +workspace-current-name "doom-modules")

;; Popup magit — workspace-scoped.
;;
;; Each Doom workspace gets its own magit-status buffer and saved window
;; config, mirroring the popup terminal behaviour. Toggle saves the current
;; layout, takes over the frame with magit-status at the project root, and
;; restores on dismiss. The magit buffer persists across toggles within the
;; same workspace.

(defvar workbench--popup-magit-configs (make-hash-table :test 'equal)
  "Hash table mapping workspace name → saved window configuration.
Non-nil entry means the popup magit is active in that workspace.")

(defun workbench--popup-magit-buffer-name ()
  "Return the popup magit buffer name for the current workspace."
  (format "*workbench-magit:%s*" (+workspace-current-name)))

(defun workbench--popup-magit-buffer ()
  "Return the magit-status buffer for the current workspace, or nil if none exists."
  (let ((name (workbench--popup-magit-buffer-name)))
    (when-let ((buf (get-buffer name)))
      (when (buffer-live-p buf)
        buf))))

(defun workbench--popup-magit-showing-p ()
  "Return non-nil if a magit-status buffer is visible in the current frame."
  (seq-some (lambda (win)
              (with-current-buffer (window-buffer win)
                (derived-mode-p 'magit-status-mode)))
            (window-list)))

(defun workbench/toggle-popup-magit ()
  "Toggle a full-frame magit-status scoped to the current workspace.
Each workspace maintains its own magit buffer and layout state independently."
  (interactive)
  (unless (fboundp 'magit-status)
    (user-error "Magit is not available"))
  (let ((ws (+workspace-current-name)))
    (if (gethash ws workbench--popup-magit-configs)
        ;; Restore previous layout
        (let ((config (gethash ws workbench--popup-magit-configs)))
          (remhash ws workbench--popup-magit-configs)
          (if (and (window-configuration-p config)
                   (eq (window-configuration-frame config) (selected-frame)))
              (set-window-configuration config)
            ;; Config is stale — just bury the magit buffer
            (when-let ((buf (workbench--popup-magit-buffer)))
              (bury-buffer buf))))
      ;; Takeover: save layout, show magit full-frame
      (puthash ws (current-window-configuration) workbench--popup-magit-configs)
      (let ((ignore-window-parameters t))
        (delete-other-windows))
      (let* ((root (workbench--project-root))
             (name (workbench--popup-magit-buffer-name))
             (existing (workbench--popup-magit-buffer)))
        (if existing
            ;; Re-display existing buffer and refresh
            (progn
              (switch-to-buffer existing)
              (magit-refresh))
          ;; Launch fresh magit-status with our buffer name.
          ;; `magit-buffer-name-format' is defvar'd by magit — declare it here
          ;; so the byte-compiler knows it's dynamically bound.
          (defvar magit-buffer-name-format)
          (let ((magit-buffer-name-format name))
            (magit-status root)))))))

;; When switching workspaces, persp restores its own window config, which
;; may conflict with the saved pre-popup layout. If we return to a workspace
;; that has popup state but no magit buffer is actually current (persp
;; overwrote it), discard the stale state so the next toggle works cleanly.
(defun workbench--popup-magit-clear-stale (&rest _)
  "Discard popup magit state if persp has already restored a different layout."
  (let ((ws (+workspace-current-name)))
    (when (and (gethash ws workbench--popup-magit-configs)
               (not (workbench--popup-magit-showing-p)))
      (remhash ws workbench--popup-magit-configs))))

(add-hook 'persp-activated-functions #'workbench--popup-magit-clear-stale)

(defun workbench--popup-magit-clear-frame (frame)
  "Remove hash entries whose saved window-configuration belongs to FRAME."
  (let ((stale-keys nil))
    (maphash (lambda (ws config)
               (when (and (window-configuration-p config)
                          (eq (window-configuration-frame config) frame))
                 (push ws stale-keys)))
             workbench--popup-magit-configs)
    (dolist (ws stale-keys)
      (remhash ws workbench--popup-magit-configs))))

(add-hook 'delete-frame-functions #'workbench--popup-magit-clear-frame)
