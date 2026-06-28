;;; system/keybindings.el -*- lexical-binding: t; -*-

(map! :leader
      :desc "Toggle project tree" "e" #'workbench/open-project-tree

      (:prefix-map ("w" . "workbench")
       :desc "Show profile" "p" #'workbench/show-profile
       :desc "Show default AI tool" "a" #'workbench/show-default-ai-tool
       :desc "Open startup workspaces" "s" #'workbench/open-startup-workspaces
       :desc "Resize windows" "r" #'workbench/resize-mode
       :desc "Switch theme" "t" #'workbench/switch-theme)

      (:prefix-map ("t" . "terminals")
       :desc "New terminal workspace" "t" #'workbench/open-terminal-workspace
       :desc "Toggle popup terminal" "p" #'workbench/toggle-popup-terminal
       :desc "Toggle Claude pane" "c" #'workbench/toggle-project-claude
       :desc "Toggle Kiro pane" "k" #'workbench/toggle-project-kiro
       :desc "Toggle Codex pane" "x" #'workbench/toggle-project-codex)

      (:prefix-map ("a" . "AI")
       :desc "Open default AI workspace" "a" #'workbench/open-default-ai-workspace
       :desc "Toggle default AI project pane" "p" #'workbench/toggle-project-ai)

      (:prefix ("f" . "files")
       :desc "Open file manager (Dirvish)" "m" #'workbench/open-files)

      (:prefix ("p" . "projects")
       :desc "Open project workspace" "o" #'workbench/open-project-workspace-dwim))

(map! "C-h" #'workbench/window-left
      "C-j" #'evil-window-down
      "C-k" #'evil-window-up
      "C-l" #'workbench/window-right)

;; Bind in evil normal/visual/motion state maps: the workspaces module binds
;; C-t to +workspace/new in `evil-normal-state-map', which outranks a plain
;; global binding.
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
