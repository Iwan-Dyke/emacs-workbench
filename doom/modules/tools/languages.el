;;; tools/languages.el -*- lexical-binding: t; -*-

;; Per-language and LSP behavior (ADR 0017, ADR 0029). The Doom :lang modules
;; and lsp-mode carry the weight; this only trims defaults. Servers are managed
;; externally and checked by bin/doctor, so don't prompt to download them.

(after! lsp-mode
  (setq lsp-headerline-breadcrumb-enable nil
        lsp-enable-suggest-server-download nil
        ;; Detect the project root from the current project instead of prompting
        ;; on the first file opened in each new project.
        lsp-auto-guess-root t))

;; SQL has no Doom :lang module, so it rides Emacs' built-in `sql-mode'. Attach
;; lsp-mode when the sqls server is installed (ADR 0029); sqls also needs a
;; connection config to be useful.
(when (executable-find "sqls")
  (add-hook 'sql-mode-hook #'lsp-deferred))
