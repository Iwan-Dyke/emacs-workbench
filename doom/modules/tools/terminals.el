;;; tools/terminals.el -*- lexical-binding: t; -*-

(require 'workbench-popup)
(declare-function workbench--project-root "modules/tools/files")

;; workbench--workspace-directories is defined in workflows/coding.el (hash-table).
;; We access it as a fallback — guarded with hash-table-p at use site.

(defun workbench/open-terminal-workspace ()
  "Open a new workspace with a fresh terminal, like a tmux new window.
Starts in the current project root (or a sensible fallback if outside a project)."
  (interactive)
  (let ((root (workbench--popup-terminal-sensible-root)))
    (+workspace/new)
    (let ((default-directory root))
      (vterm (generate-new-buffer-name "*terminal*")))))

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

(defvar workbench--popup-terminal-buffers (make-hash-table :test 'equal)
  "Hash table mapping workspace name → popup terminal buffer.")

(defun workbench--popup-terminal-buffer-name ()
  "Return the popup buffer name for the current workspace."
  (format "*workbench-popup-term:%s*" (+workspace-current-name)))

(defun workbench--popup-terminal-sensible-root ()
  "Return a sensible root for the popup terminal.
Prefers the project root. If that's just ~ or /, tries the workspace's
registered directory, then falls back to `workbench-jira-code-root'."
  (let ((root (workbench--project-root)))
    (if (and root
             (not (equal (file-truename root) (file-truename "~/")))
             (not (equal root "/")))
        root
      ;; Try workspace directory registry
      (or (and (boundp 'workbench--workspace-directories)
               (hash-table-p workbench--workspace-directories)
               (gethash (+workspace-current-name) workbench--workspace-directories))
          (expand-file-name (bound-and-true-p workbench-code-root))))))

(defun workbench--popup-terminal-buffer ()
  "Return the popup terminal vterm buffer for the current workspace.
Creates a new buffer at the project root if one doesn't exist yet.
Kills and recreates the buffer if it exists but is not in vterm-mode (e.g.
after a failed vterm-mode init). Defers `vterm-mode' until after the buffer
is displayed so the terminal gets correct window dimensions on first draw."
  (let* ((name (workbench--popup-terminal-buffer-name))
         (buffer (get-buffer name)))
    (if (and (buffer-live-p buffer)
             (with-current-buffer buffer (derived-mode-p 'vterm-mode)))
        (progn
          (puthash (+workspace-current-name) buffer workbench--popup-terminal-buffers)
          buffer)
      ;; Buffer is dead or not in vterm-mode — kill and start fresh
      (when (buffer-live-p buffer)
        (kill-buffer buffer))
      (let ((root (workbench--popup-terminal-sensible-root)))
        (with-current-buffer (get-buffer-create name)
          (setq default-directory root)
          (puthash (+workspace-current-name) (current-buffer) workbench--popup-terminal-buffers)
          (current-buffer))))))

(defun workbench--popup-terminal-showing-p ()
  "Return non-nil if the popup terminal buffer is currently displayed."
  (let ((buf (get-buffer (workbench--popup-terminal-buffer-name))))
    (and (buffer-live-p buf)
         (get-buffer-window buf))))

(defun workbench--popup-terminal-primary-window ()
  "Return the best window to return focus to after dismissing the popup.
Delegates to the shared popup infrastructure."
  (workbench-popup-primary-window))

(defun workbench/toggle-popup-terminal ()
  "Toggle a full-frame project shell scoped to the current workspace.
Each workspace maintains its own terminal and layout state independently.
On dismiss, selects the primary editing window rather than whichever window
was focused when the popup was opened."
  (interactive)
  (let ((ws (+workspace-current-name)))
    (if (or (workbench--popup-terminal-showing-p)
            (gethash ws workbench--popup-terminal-configs))
        ;; Hide — delegate to shared popup infrastructure
        (workbench-popup-hide workbench--popup-terminal-configs
                              (get-buffer (workbench--popup-terminal-buffer-name)))
      ;; Show — delegate frame preparation, then show terminal
      (workbench-popup-show-prepare workbench--popup-terminal-configs)
      (let ((buf (workbench--popup-terminal-buffer)))
        (switch-to-buffer buf)
        (unless (derived-mode-p 'vterm-mode)
          (condition-case err
              (vterm-mode)
            (error
             (let ((config (gethash ws workbench--popup-terminal-configs)))
               (remhash ws workbench--popup-terminal-configs)
               (when (window-configuration-p config)
                 (set-window-configuration config)))
             (user-error "vterm-mode failed: %s" (error-message-string err)))))))))

;; Workspace switch and frame deletion cleanup via shared popup infrastructure.
(defun workbench--popup-terminal-clear-stale (&rest _)
  "Discard stale popup terminal state when workspace layout changes."
  (workbench-popup-clear-stale workbench--popup-terminal-configs
                               workbench--popup-terminal-buffers
                               #'workbench--popup-terminal-showing-p))

(defun workbench--popup-terminal-clear-frame (frame)
  "Remove popup terminal entries for FRAME on frame deletion."
  (workbench-popup-clear-frame workbench--popup-terminal-configs
                               workbench--popup-terminal-buffers
                               frame))

(add-hook 'persp-activated-functions #'workbench--popup-terminal-clear-stale)
(add-hook 'delete-frame-functions #'workbench--popup-terminal-clear-frame)
