;;; tools/terminals.el -*- lexical-binding: t; -*-

(require 'seq)
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
          (expand-file-name (or (bound-and-true-p workbench-jira-code-root) "~/code/"))))))

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
        buffer
      ;; Buffer is dead or not in vterm-mode — kill and start fresh
      (when (buffer-live-p buffer)
        (kill-buffer buffer))
      (let ((root (workbench--popup-terminal-sensible-root)))
        (with-current-buffer (get-buffer-create name)
          (setq default-directory root)
          (current-buffer))))))

(defun workbench--popup-terminal-showing-p ()
  "Return non-nil if the popup terminal buffer is currently displayed."
  (let ((buf (get-buffer (workbench--popup-terminal-buffer-name))))
    (and (buffer-live-p buf)
         (get-buffer-window buf))))

(defun workbench--popup-terminal-primary-window ()
  "Return the best window to return focus to after dismissing the popup.
Prefers a window showing a file-visiting or code buffer over AI panes,
Treemacs, or special buffers. Falls back to the selected window."
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

(defun workbench/toggle-popup-terminal ()
  "Toggle a full-frame project shell scoped to the current workspace.
Each workspace maintains its own terminal and layout state independently.
On dismiss, selects the primary editing window rather than whichever window
was focused when the popup was opened."
  (interactive)
  (let ((ws (+workspace-current-name)))
    (if (or (workbench--popup-terminal-showing-p)
            (gethash ws workbench--popup-terminal-configs))
        ;; Hide — restore previous layout
        (let ((config (gethash ws workbench--popup-terminal-configs)))
          (remhash ws workbench--popup-terminal-configs)
          (cond
           ;; Valid config for this frame — restore it
           ((and (window-configuration-p config)
                 (eq (window-configuration-frame config) (selected-frame)))
            (set-window-configuration config)
            ;; After restoring, select the primary editing window so the user
            ;; doesn't land in the AI pane or Treemacs regardless of where
            ;; they originally toggled from.
            (select-window (workbench--popup-terminal-primary-window)))
           ;; Stale or missing config — bury and switch to a sensible buffer
           (t
            (when-let ((buf (get-buffer (workbench--popup-terminal-buffer-name))))
              (bury-buffer buf))
            ;; Try to show the workspace's previous buffer rather than leaving
            ;; the user staring at a random or dead buffer.
            (when (eq (current-buffer) (get-buffer (workbench--popup-terminal-buffer-name)))
              (switch-to-buffer (other-buffer (current-buffer) t))))))
      ;; Show — save layout and take over the frame.
      ;; If the selected window is dedicated (e.g. Treemacs), select a
      ;; non-dedicated window first so that switch-to-buffer works.
      (when (window-dedicated-p)
        (let ((target (seq-find (lambda (w) (not (window-dedicated-p w)))
                                (window-list))))
          (when target (select-window target))))
      (unless (gethash ws workbench--popup-terminal-configs)
        (puthash ws (current-window-configuration) workbench--popup-terminal-configs))
      (let ((ignore-window-parameters t))
        (delete-other-windows))
      ;; After delete-other-windows, clear any residual window dedication
      ;; on the sole remaining window so switch-to-buffer succeeds.
      (set-window-dedicated-p (selected-window) nil)
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
