;;; init.el -*- lexical-binding: t; -*-

(doom! :input
       :completion
       company
       vertico

       :ui
       doom
       dashboard
       modeline
       workspaces

       :editor
       evil

       :emacs
       dired

       :term
       vterm

       :tools
       magit

       :config
       (default +bindings +smartparens))
