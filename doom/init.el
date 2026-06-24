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
       format
       snippets

       :emacs
       (dired +dirvish)

       :term
       vterm

       :checkers
       syntax

       :tools
       lookup
       lsp
       magit
       (docker +lsp)
       (terraform +lsp)

       :lang
       emacs-lisp
       (python +lsp +pyright)
       (go +lsp)
       (sh +lsp)
       (lua +lsp)
       (yaml +lsp)
       markdown
       org

       :config
       (default +bindings +smartparens))
