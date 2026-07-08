;;; tools/terminals.el -*- lexical-binding: t; -*-

(declare-function workbench--project-root "modules/tools/files")

(defun workbench/open-terminal-workspace ()
  "Open a new workspace with a fresh terminal, like a tmux new window."
  (interactive)
  (+workspace/new)
  (let ((default-directory "~/"))
    (vterm (generate-new-buffer-name "*terminal*"))))

;; Popup terminal — workspace-scoped.
;;
;; Each Doom workspace gets its own popup terminal buffer and saved window
;; config, mirroring the Neovim toggleterm behaviour where each tmux pane
;; has its own popup. The terminal starts in the project root and persists
;; across toggles within the same workspace.

;; Why a hash table instead of a buffer-name convention (like AI panes)?
;; The popup terminal saves/restores a full window-configuration object per
;; workspace — that cannot be encoded in a buffer name. AI panes only need
;; show/hide (window exists or not), so a naming convention suffices there.
(defvar workbench--popup-terminal-configs (make-hash-table :test 'equal)
  "Hash table mapping workspace name → saved window configuration.
Non-nil entry means the popup is active in that workspace.")

(defun workbench--popup-terminal-buffer-name ()
  "Return the popup buffer name for the current workspace."
  (format "*workbench-popup-term:%s*" (+workspace-current-name)))

(defun workbench--popup-terminal-buffer ()
  "Return the popup terminal vterm buffer for the current workspace.
Creates a new buffer at the project root if one doesn't exist yet.
Defers `vterm-mode' until after the buffer is displayed so the terminal
gets correct window dimensions on first draw."
  (let* ((name (workbench--popup-terminal-buffer-name))
         (buffer (get-buffer name)))
    (if (and (buffer-live-p buffer)
             (with-current-buffer buffer (derived-mode-p 'vterm-mode)))
        buffer
      (let ((root (workbench--project-root)))
        (with-current-buffer (get-buffer-create name)
          (setq default-directory root)
          (current-buffer))))))

(defun workbench--popup-terminal-showing-p ()
  "Return non-nil if the popup terminal buffer is currently displayed."
  (let ((buf (get-buffer (workbench--popup-terminal-buffer-name))))
    (and (buffer-live-p buf)
         (eq (current-buffer) buf))))

(defun workbench/toggle-popup-terminal ()
  "Toggle a full-frame project shell scoped to the current workspace.
Each workspace maintains its own terminal and layout state independently."
  (interactive)
  (let ((ws (+workspace-current-name)))
    (if (workbench--popup-terminal-showing-p)
        ;; Hide — restore previous layout
        (let ((config (gethash ws workbench--popup-terminal-configs)))
          (remhash ws workbench--popup-terminal-configs)
          (cond
           ;; Valid config for this frame — restore it
           ((and (window-configuration-p config)
                 (eq (window-configuration-frame config) (selected-frame)))
            (set-window-configuration config))
           ;; Stale or missing config — bury and switch to a sensible buffer
           (t
            (when-let ((buf (get-buffer (workbench--popup-terminal-buffer-name))))
              (bury-buffer buf))
            ;; Try to show the workspace's previous buffer rather than leaving
            ;; the user staring at a random or dead buffer.
            (when (eq (current-buffer) (get-buffer (workbench--popup-terminal-buffer-name)))
              (switch-to-buffer (other-buffer (current-buffer) t))))))
      ;; Show — save layout and take over the frame
      (puthash ws (current-window-configuration) workbench--popup-terminal-configs)
      (let ((ignore-window-parameters t))
        (delete-other-windows))
      (let ((buf (workbench--popup-terminal-buffer)))
        (switch-to-buffer buf)
        (unless (derived-mode-p 'vterm-mode)
          (vterm-mode))))))

;; When switching workspaces, persp restores its own window config, which
;; may conflict with the saved pre-popup layout in the hash table. If we
;; return to a workspace that has popup state but the popup buffer isn't
;; actually the current buffer (persp overwrote it), discard the stale state
;; so C-t works cleanly as a fresh toggle.
(defun workbench--popup-terminal-clear-stale (&rest _)
  "Discard popup state if persp has already restored a different layout.
When switching workspaces, persp restores its saved window-config which
overwrites whatever was on screen. If there was popup state saved for the
workspace we're entering, but the popup buffer isn't actually visible,
the saved config is stale and toggling would restore a nonsensical layout."
  (let* ((ws (+workspace-current-name))
         (popup-buf (get-buffer (format "*workbench-popup-term:%s*" ws))))
    (when (and (gethash ws workbench--popup-terminal-configs)
               (not (and (buffer-live-p popup-buf)
                         (get-buffer-window popup-buf))))
      (remhash ws workbench--popup-terminal-configs))))

(add-hook 'persp-activated-functions #'workbench--popup-terminal-clear-stale)

(defun workbench--popup-terminal-clear-frame (frame)
  "Remove hash entries whose saved window-configuration belongs to FRAME."
  (let ((stale-keys nil))
    (maphash (lambda (ws config)
               (when (and (window-configuration-p config)
                          (eq (window-configuration-frame config) frame))
                 (push ws stale-keys)))
             workbench--popup-terminal-configs)
    (dolist (ws stale-keys)
      (remhash ws workbench--popup-terminal-configs))))

(add-hook 'delete-frame-functions #'workbench--popup-terminal-clear-frame)
