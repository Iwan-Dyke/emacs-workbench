;;; tools/git.el -*- lexical-binding: t; -*-

(require 'seq)
(declare-function workbench--project-root "modules/tools/files")
(declare-function workbench--popup-terminal-primary-window "modules/tools/terminals")
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
On dismiss, selects the primary editing window rather than whichever window
was focused when the popup was opened."
  (interactive)
  (unless (fboundp 'magit-status)
    (user-error "Magit is not available"))
  (let ((ws (+workspace-current-name)))
    (if (or (gethash ws workbench--popup-magit-configs)
            (workbench--popup-magit-showing-p))
        ;; Restore previous layout
        (let ((config (gethash ws workbench--popup-magit-configs)))
          (remhash ws workbench--popup-magit-configs)
          (if (and (window-configuration-p config)
                   (eq (window-configuration-frame config) (selected-frame)))
              (progn
                (set-window-configuration config)
                (select-window (workbench--popup-terminal-primary-window)))
            ;; Config is stale — just bury the magit buffer
            (when-let ((buf (workbench--popup-magit-buffer)))
              (bury-buffer buf))
            (select-window (workbench--popup-terminal-primary-window))))
      ;; Takeover: save layout, show magit full-frame.
      ;; If the selected window is dedicated (e.g. Treemacs), select a
      ;; non-dedicated window first so that switch-to-buffer works.
      (when (window-dedicated-p)
        (let ((target (seq-find (lambda (w) (not (window-dedicated-p w)))
                                (window-list))))
          (if target
              (select-window target)
            ;; All windows dedicated (e.g. Treemacs-only frame edge case) —
            ;; clear dedication so we can proceed with switch-to-buffer.
            (set-window-dedicated-p (selected-window) nil))))
      (unless (gethash ws workbench--popup-magit-configs)
        (puthash ws (current-window-configuration) workbench--popup-magit-configs))
      (let ((ignore-window-parameters t))
        (delete-other-windows))
      (set-window-dedicated-p (selected-window) nil)
      (let* ((root (workbench--project-root))
             (existing (workbench--popup-magit-buffer)))
        (if existing
            ;; Re-display existing buffer and refresh
            (progn
              (switch-to-buffer existing)
              (magit-refresh))
          ;; Launch fresh magit-status and track the buffer magit creates.
          (magit-status root)
          (puthash ws (current-buffer) workbench--popup-magit-buffers))))))

;; When switching workspaces, persp restores its own window config, which
;; may conflict with the saved pre-popup layout. If we return to a workspace
;; that has popup state but no magit buffer is actually current (persp
;; overwrote it), discard the stale state so the next toggle works cleanly.
(defun workbench--popup-magit-clear-stale (&rest _)
  "Discard popup magit state if persp has already restored a different layout.
Only clears state when the tracked magit buffer is dead. If it is alive but
not visible, persp merely restored a different layout — the buffer is still
valid for next toggle, so keep the hash entry."
  (let ((ws (+workspace-current-name)))
    (when (and (gethash ws workbench--popup-magit-configs)
               (not (workbench--popup-magit-showing-p)))
      ;; Config is stale (magit not showing), but only discard if buffer is dead.
      (let ((buf (gethash ws workbench--popup-magit-buffers)))
        (if (and buf (buffer-live-p buf))
            ;; Buffer alive but not visible — just clear the window config
            ;; so next toggle re-saves layout, but keep the buffer reference.
            (remhash ws workbench--popup-magit-configs)
          ;; Buffer is dead — full cleanup.
          (remhash ws workbench--popup-magit-configs)
          (remhash ws workbench--popup-magit-buffers))))))

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
      (remhash ws workbench--popup-magit-configs)
      (remhash ws workbench--popup-magit-buffers))))

(add-hook 'delete-frame-functions #'workbench--popup-magit-clear-frame)
