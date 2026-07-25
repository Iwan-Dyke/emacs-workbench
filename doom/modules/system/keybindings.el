;;; system/keybindings.el -*- lexical-binding: t; -*-

(map! :leader
      :desc "Toggle project tree" "e" #'workbench/open-project-tree

      (:prefix-map ("w" . "workbench")
       :desc "Show profile" "p" #'workbench/show-profile
       :desc "Show default AI tool" "a" #'workbench/show-default-ai-tool
       :desc "Open startup workspaces" "s" #'workbench/open-startup-workspaces
       :desc "Resize windows" "r" #'workbench/resize-mode
       :desc "Switch theme" "t" #'workbench/switch-theme)

      (:prefix-map ("n" . "notes")
       :desc "Open agenda" "a" #'workbench-org/open-agenda
       :desc "Weeknote" "w" #'workbench-org/open-weeknote
       :desc "Find node" "f" #'org-roam-node-find
       :desc "Insert link" "i" #'org-roam-node-insert
       :desc "Backlinks" "b" #'org-roam-buffer-toggle
       :desc "Capture" "c" #'org-capture
       :desc "Discover ADRs" "d" #'workbench-org-discover-adrs
       :desc "Open jira.org" "j" #'workbench-org/open-jira-file)

      (:prefix-map ("t" . "terminals")
       :desc "New terminal workspace" "t" #'workbench/open-terminal-workspace
       :desc "Toggle popup terminal" "p" #'workbench/toggle-popup-terminal
       :desc "Toggle Claude pane" "c" #'workbench/toggle-project-claude
       :desc "Toggle Kiro pane" "k" #'workbench/toggle-project-kiro
       :desc "Toggle Codex pane" "x" #'workbench/toggle-project-codex)

      (:prefix-map ("a" . "AI")
       :desc "Open default AI workspace" "a" #'workbench/open-default-ai-workspace
       :desc "Toggle default AI project pane" "p" #'workbench/toggle-project-ai)

      (:prefix ("g" . "git")
       :desc "Toggle popup magit" "g" #'workbench/toggle-popup-magit)

      (:prefix ("f" . "files")
       :desc "Open file manager (Dirvish)" "m" #'workbench/open-files)

      (:prefix ("p" . "projects")
       :desc "Open project workspace" "o" #'workbench/open-project-workspace-dwim))

(map! :nvm "C-h" #'workbench/window-left
      :nvm "C-j" #'evil-window-down
      :nvm "C-k" #'evil-window-up
      :nvm "C-l" #'workbench/window-right)

;; Doom's workspaces module binds C-t to +workspace/new in
;; `evil-normal-state-map'. That binding can re-assert after our module loads
;; (workspace state reinitialisation on later frame/persp events). A simple
;; (after! persp-mode (define-key ...)) only fires once at load time and gets
;; overwritten. Instead, use an advice that strips the binding every time
;; persp-mode tries to set it up, then bind C-t via general-override which
;; has higher priority than evil state maps.
(after! persp-mode
  (define-key evil-normal-state-map (kbd "C-t") nil)
  (define-key evil-visual-state-map (kbd "C-t") nil)
  (define-key evil-motion-state-map (kbd "C-t") nil))

;; Persistent: re-assert our binding any time persp overwrites it
(defun workbench--strip-persp-ct (&rest _)
  "Ensure C-t is bound to popup terminal, not Doom's +workspace/new."
  (define-key evil-normal-state-map (kbd "C-t") #'workbench/toggle-popup-terminal)
  (define-key evil-visual-state-map (kbd "C-t") #'workbench/toggle-popup-terminal)
  (define-key evil-motion-state-map (kbd "C-t") #'workbench/toggle-popup-terminal))

(add-hook 'persp-mode-hook #'workbench--strip-persp-ct)
(add-hook 'persp-activated-functions #'workbench--strip-persp-ct)
(add-hook 'after-make-frame-functions #'workbench--strip-persp-ct)

(map! :nvm "C-t" #'workbench/toggle-popup-terminal)

;; ── Global coverage for window navigation and popup terminal ──────────────
;;
;; The :nvm bindings above only cover normal/visual/motion states. Treemacs
;; uses a custom `treemacs' evil state and some special buffers use `emacs'
;; state (e.g. command-centre, magit-popup). Bind C-t and C-h/j/k/l in those
;; additional states so navigation works from ANY pane in the workspace.

(after! treemacs
  (evil-define-key 'treemacs treemacs-mode-map
    (kbd "C-t") #'workbench/toggle-popup-terminal
    (kbd "C-h") #'workbench/window-left
    (kbd "C-j") #'evil-window-down
    (kbd "C-k") #'evil-window-up
    (kbd "C-l") #'workbench/window-right))

;; Emacs state: covers special-mode buffers (command centre, help, etc.)
;; NOTE: C-h is intentionally NOT bound here — it shadows the Emacs help
;; system in emacs-state buffers. Use C-l or other window commands instead.
(define-key evil-emacs-state-map (kbd "C-t") #'workbench/toggle-popup-terminal)
(define-key evil-emacs-state-map (kbd "C-j") #'evil-window-down)
(define-key evil-emacs-state-map (kbd "C-k") #'evil-window-up)
(define-key evil-emacs-state-map (kbd "C-l") #'workbench/window-right)

(after! vterm
  (setq vterm-keymap-exceptions
        (delete-dups (append '("C-t" "C-h" "C-j" "C-k" "C-l") vterm-keymap-exceptions)))
  (map! :map vterm-mode-map
        "C-c C-c" #'vterm-send-C-c
        "C-h" #'workbench/window-left
        "C-j" #'evil-window-down
        "C-k" #'evil-window-up
        "C-l" #'workbench/window-right
        "C-t" #'workbench/toggle-popup-terminal)

  ;; Paste into vterm — evil-paste-after fails because vterm buffers are
  ;; read-only. Override p/P/C-y/Cmd+v to use vterm-yank which sends the
  ;; kill-ring content through the pty to the running process.
  (evil-define-key 'normal vterm-mode-map
    "p" #'vterm-yank
    "P" #'vterm-yank)
  (evil-define-key 'insert vterm-mode-map
    (kbd "C-y") #'vterm-yank)
  (map! :map vterm-mode-map
        "s-v" #'vterm-yank))

;;; ── Org Agenda ─────────────────────────────────────────────────────────────

(after! org-agenda
  (evil-set-initial-state 'org-agenda-mode 'normal)
  (evil-define-key 'normal org-agenda-mode-map
    "j" #'org-agenda-next-line
    "k" #'org-agenda-previous-line
    (kbd "RET") #'org-agenda-switch-to
    "o" #'org-agenda-open-link
    "t" #'org-agenda-todo
    "s" #'org-agenda-schedule
    "d" #'org-agenda-deadline
    "r" #'org-agenda-redo
    "q" #'org-agenda-quit
    "i" #'org-agenda-clock-in
    "O" #'org-agenda-clock-out
    "/" #'org-agenda-filter-by-tag
    "f" #'org-agenda-later
    "b" #'org-agenda-earlier))
