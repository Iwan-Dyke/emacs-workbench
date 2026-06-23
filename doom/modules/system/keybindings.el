;;; system/keybindings.el -*- lexical-binding: t; -*-

(map! :leader
      (:prefix-map ("w" . "workbench")
       :desc "Show profile" "p" #'workbench/show-profile
       :desc "Show default AI tool" "a" #'workbench/show-default-ai-tool))
