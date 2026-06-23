;;; init.el -*- lexical-binding: t; -*-

(doom! :input
       :completion
       company
       vertico

       :ui
       doom
       doom-dashboard
       modeline

       :editor
       evil

       :emacs
       dired

       :term
       vterm

       :tools
       magit

       :config
       literate
       (default +bindings +smartparens))
