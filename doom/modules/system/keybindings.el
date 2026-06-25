;;; system/keybindings.el -*- lexical-binding: t; -*-

(map! :leader
      :desc "Toggle project tree" "e" #'workbench/open-project-tree

      (:prefix-map ("w" . "workbench")
       :desc "Show profile" "p" #'workbench/show-profile
       :desc "Show default AI tool" "a" #'workbench/show-default-ai-tool
       :desc "Open startup workspaces" "s" #'workbench/open-startup-workspaces
       :desc "Resize windows" "r" #'workbench/resize-mode)

      (:prefix-map ("t" . "terminals")
       :desc "New terminal workspace" "t" #'workbench/open-terminal-workspace
       :desc "Toggle popup terminal" "p" #'workbench/toggle-popup-terminal
       :desc "Toggle Claude pane" "c" #'workbench/toggle-project-claude
       :desc "Toggle Kiro pane" "k" #'workbench/toggle-project-kiro
       :desc "Toggle Codex pane" "x" #'workbench/toggle-project-codex)

      (:prefix-map ("a" . "AI")
       :desc "Open default AI workspace" "a" #'workbench/open-default-ai-workspace
       :desc "Toggle default AI project pane" "p" #'workbench/toggle-project-ai)

      (:prefix-map ("q" . "quit/session")
       :desc "Close frame" "f" #'workbench/close-frame
       :desc "Stop daemon" "q" #'workbench/stop-daemon)

      (:prefix-map ("f" . "files")
       :desc "Find file in project" "f" #'project-find-file
       :desc "Open file manager (Dirvish)" "m" #'workbench/open-files)

      (:prefix ("c" . "code")
       :desc "Format buffer/region" "f" #'+format/region-or-buffer)

      (:prefix-map ("g" . "git")
       :desc "Open Git status" "g" #'workbench/open-git)

      (:prefix-map ("p" . "projects")
       :desc "Switch project" "p" #'workbench/switch-project
       :desc "Find project file" "f" #'workbench/find-project-file
       :desc "Search project" "s" #'workbench/search-project
       :desc "Open project workspace" "o" #'workbench/open-project-workspace-dwim))

;; tmux-like window navigation matching the Neovim C-h/j/k/l motions.
;; This takes C-h from the help prefix; help remains available on SPC h.
(map! "C-h" #'workbench/window-left
      "C-j" #'evil-window-down
      "C-k" #'evil-window-up
      "C-l" #'workbench/window-right)

;; Popup terminal, mirroring the Neovim toggleterm C-t. Bind in the evil
;; normal/visual/motion state maps, not just the global map: the workspaces
;; module binds C-t to +workspace/new in `evil-normal-state-map', which outranks
;; a plain global binding and was silently spawning a workspace instead. Insert
;; state is left alone (so C-t still types normally while editing); the terminal
;; gets its own binding in the vterm block below.
(map! :nvm "C-t" #'workbench/toggle-popup-terminal)

;; Keep window navigation working from inside vterm (e.g. the AI pane),
;; so the terminal is never a focus trap (ADR 0048).
(after! vterm
  (map! :map vterm-mode-map
        "C-h" #'workbench/window-left
        "C-j" #'evil-window-down
        "C-k" #'evil-window-up
        "C-l" #'workbench/window-right
        ;; Dismiss the popup from inside it, like toggleterm's terminal-mode C-t.
        "C-t" #'workbench/toggle-popup-terminal))
