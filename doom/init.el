;;; init.el -*- lexical-binding: t; -*-

(doom! :input
       :completion
       company
       vertico

       :ui
       doom
       dashboard
       modeline
       treemacs
       workspaces

       :editor
       evil

       :emacs
       (dired +dirvish)

       :term
       vterm

       :tools
       magit

       :config
       (default +bindings +smartparens))
