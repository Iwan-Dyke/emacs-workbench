;;; tools/terminals.el -*- lexical-binding: t; -*-

(defun workbench/open-terminal-workspace ()
  "Open a new workspace with a fresh terminal, like a tmux new window.
Type whatever you want in it: a shell command or an AI agent."
  (interactive)
  (+workspace/new)
  (vterm (generate-new-buffer-name "*terminal*")))

;; Popup terminal: a single persistent project shell that takes over the whole
;; frame on C-t (and SPC t p) and restores the previous layout on C-t again.
;; Ported from the Neovim toggleterm C-t float for quick project-level shell
;; work like git.
;;
;; This stays inside the current frame on purpose. A floating child frame matched
;; the look but is unusable on Wayland (WSLg): keyboard focus cannot be returned
;; to the parent when the popup closes, leaving the editor unresponsive until the
;; whole frame is recreated. A saved/restored window configuration has none of
;; that — no new frame, no persp workspace, no focus handover.

(defvar workbench--popup-terminal-buffer-name "*workbench-popup-term*"
  "Buffer name of the persistent popup terminal shell.")

(defvar workbench--popup-terminal-saved-window-config nil
  "Window configuration saved before the popup took over the frame.
Non-nil exactly while the popup is active, so it doubles as the toggle state.")

(defun workbench--popup-terminal-buffer ()
  "Return the popup terminal vterm buffer, creating it at the project root.
The shell is started once and reused across toggles."
  (let ((buffer (get-buffer workbench--popup-terminal-buffer-name)))
    (if (buffer-live-p buffer)
        buffer
      (let ((root (workbench--project-root)))
        (with-current-buffer (get-buffer-create workbench--popup-terminal-buffer-name)
          (setq default-directory root)
          (unless (derived-mode-p 'vterm-mode)
            (vterm-mode))
          (current-buffer))))))

(defun workbench--popup-terminal-takeover ()
  "Save the current layout and fill the frame with the popup terminal.
`ignore-window-parameters' lets `delete-other-windows' remove side windows too
\(e.g. the AI pane), so the terminal truly fills the frame; the saved window
configuration restores them on exit."
  (setq workbench--popup-terminal-saved-window-config
        (current-window-configuration))
  (let ((ignore-window-parameters t))
    (delete-other-windows))
  (switch-to-buffer (workbench--popup-terminal-buffer)))

(defun workbench--popup-terminal-restore ()
  "Restore the layout saved before the popup took over the frame."
  (let ((config workbench--popup-terminal-saved-window-config))
    (setq workbench--popup-terminal-saved-window-config nil)
    (when (window-configuration-p config)
      (set-window-configuration config))))

(defun workbench/toggle-popup-terminal ()
  "Toggle a full-frame project shell, restoring the previous layout on exit.
A single persistent shell for quick project-level work (git, etc.); the same
key dismisses it from inside the terminal. The vterm buffer is reused across
toggles, so the shell and its state persist."
  (interactive)
  (if workbench--popup-terminal-saved-window-config
      (workbench--popup-terminal-restore)
    (workbench--popup-terminal-takeover)))
