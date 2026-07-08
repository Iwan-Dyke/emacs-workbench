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

(map! "C-h" #'workbench/window-left
      "C-j" #'evil-window-down
      "C-k" #'evil-window-up
      "C-l" #'workbench/window-right)

;; Doom's workspaces module binds C-t to +workspace/new in
;; `evil-normal-state-map'. That binding can re-assert after our module loads
;; (workspace state reinitialisation on later frame/persp events), so unbind
;; it explicitly after the module is present, then set ours.
(after! persp-mode
  (define-key evil-normal-state-map (kbd "C-t") nil)
  (define-key evil-visual-state-map (kbd "C-t") nil)
  (define-key evil-motion-state-map (kbd "C-t") nil))
(map! :nvm "C-t" #'workbench/toggle-popup-terminal)

(after! vterm
  (setq vterm-keymap-exceptions
        (delete-dups (append '("C-t" "C-j" "C-k") vterm-keymap-exceptions)))
  (map! :map vterm-mode-map
        "C-c C-c" #'vterm-send-C-c
        "C-h" #'workbench/window-left
        "C-j" #'evil-window-down
        "C-k" #'evil-window-up
        "C-l" #'workbench/window-right
        "C-t" #'workbench/toggle-popup-terminal))

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
