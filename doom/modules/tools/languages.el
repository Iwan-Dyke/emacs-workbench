;;; tools/languages.el -*- lexical-binding: t; -*-

(after! lsp-mode
  (setq lsp-headerline-breadcrumb-enable nil
        lsp-enable-suggest-server-download nil
        ;; Detect the project root from the current project instead of prompting
        ;; on the first file opened in each new project.
        lsp-auto-guess-root t))

(when (executable-find "sqls")
  (add-hook 'sql-mode-hook #'lsp-deferred))
