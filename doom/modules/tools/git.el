;;; tools/git.el -*- lexical-binding: t; -*-

(require 'seq)
(require 'workbench-popup)
(declare-function workbench--project-root "modules/tools/files")
(declare-function magit-status "magit-status")
(declare-function magit-refresh "magit-mode")
(declare-function +workspace-current-name "doom-modules")

;; Popup magit — workspace-scoped, using shared popup infrastructure.
;;
;; Each Doom workspace gets its own magit-status buffer and saved window
;; config. Toggle saves the current layout, takes over the frame with
;; magit-status at the project root, and restores on dismiss.

(defvar workbench--popup-magit-configs (make-hash-table :test 'equal)
  "Hash table mapping workspace name → saved window configuration.
Non-nil entry means the popup magit is active in that workspace.")

(defvar workbench--popup-magit-buffers (make-hash-table :test 'equal)
  "Hash table mapping workspace name → magit-status buffer.")

(defun workbench--popup-magit-buffer ()
  "Return the live magit-status buffer for the current workspace, or nil."
  (let ((buf (gethash (+workspace-current-name) workbench--popup-magit-buffers)))
    (when (buffer-live-p buf)
      buf)))

(defun workbench--popup-magit-showing-p ()
  "Return non-nil if a magit-status buffer is visible in the current frame."
  (seq-some (lambda (win)
              (with-current-buffer (window-buffer win)
                (derived-mode-p 'magit-status-mode)))
            (window-list)))

(defun workbench/toggle-popup-magit ()
  "Toggle a full-frame magit-status scoped to the current workspace.
Each workspace maintains its own magit buffer and layout state independently.
On dismiss, selects the primary editing window."
  (interactive)
  (unless (fboundp 'magit-status)
    (user-error "Magit is not available"))
  (let ((ws (+workspace-current-name)))
    (if (or (gethash ws workbench--popup-magit-configs)
            (workbench--popup-magit-showing-p))
        ;; Hide — delegate to shared popup infrastructure
        (workbench-popup-hide workbench--popup-magit-configs
                              (workbench--popup-magit-buffer))
      ;; Show — delegate frame preparation, then show magit
      (workbench-popup-show-prepare workbench--popup-magit-configs)
      (let* ((root (workbench--project-root))
             (existing (workbench--popup-magit-buffer)))
        (if existing
            (progn
              (switch-to-buffer existing)
              (magit-refresh))
          (magit-status root)
          (puthash ws (current-buffer) workbench--popup-magit-buffers))))))

;; Workspace switch and frame deletion cleanup via shared infrastructure.
(defun workbench--popup-magit-clear-stale (&rest _)
  "Discard stale popup magit state when workspace layout changes."
  (workbench-popup-clear-stale workbench--popup-magit-configs
                               workbench--popup-magit-buffers
                               #'workbench--popup-magit-showing-p))

(defun workbench--popup-magit-clear-frame (frame)
  "Remove popup magit entries for FRAME on frame deletion."
  (workbench-popup-clear-frame workbench--popup-magit-configs
                               workbench--popup-magit-buffers
                               frame))

(add-hook 'persp-activated-functions #'workbench--popup-magit-clear-stale)
(add-hook 'delete-frame-functions #'workbench--popup-magit-clear-frame)
