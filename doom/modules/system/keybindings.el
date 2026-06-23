;;; system/keybindings.el -*- lexical-binding: t; -*-

(map! :leader
      (:prefix-map ("w" . "workbench")
       :desc "Show profile" "p" #'workbench/show-profile
       :desc "Show default AI tool" "a" #'workbench/show-default-ai-tool)

      (:prefix-map ("t" . "terminals")
       :desc "Open terminal" "t" #'workbench/open-terminal)

      (:prefix-map ("a" . "AI")
       :desc "Open default AI" "a" #'workbench/open-default-ai
       :desc "Open Codex" "c" #'workbench/open-codex
       :desc "Open Kiro" "k" #'workbench/open-kiro
       :desc "Open Claude" "l" #'workbench/open-claude)

      (:prefix-map ("q" . "quit/session")
       :desc "Close frame" "f" #'workbench/close-frame
       :desc "Stop daemon" "q" #'workbench/stop-daemon)

      (:prefix-map ("f" . "files")
       :desc "Open files" "f" #'workbench/open-files)

      (:prefix-map ("g" . "git")
       :desc "Open Git status" "g" #'workbench/open-git)

      (:prefix-map ("p" . "projects")
       :desc "Switch project" "p" #'workbench/switch-project
       :desc "Find project file" "f" #'workbench/find-project-file
       :desc "Search project" "s" #'workbench/search-project))
