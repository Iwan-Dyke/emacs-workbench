;;; tools/languages.el -*- lexical-binding: t; -*-

(after! lsp-mode
  (setq lsp-headerline-breadcrumb-enable nil
        lsp-enable-suggest-server-download nil
        ;; Detect the project root from the current project instead of prompting
        ;; on the first file opened in each new project.
        lsp-auto-guess-root t))

(when (executable-find "sqls")
  (add-hook 'sql-mode-hook #'lsp-deferred))

;; ─── Markdown ────────────────────────────────────────────────────────────────
;; Render via pandoc into xwidget-webkit (in-Emacs) or browser.
;; C-c C-c p to preview rendered HTML.
(after! markdown-mode
  (setq markdown-command `("pandoc" "-f" "markdown" "-t" "html5" "--standalone"
                           "--metadata" "title= "
                           "--css" ,(expand-file-name "pandoc/preview.css"
                                                     (or (getenv "XDG_CONFIG_HOME")
                                                         "~/.config"))
                           "--embed-resources"
                           "--lua-filter" ,(expand-file-name "pandoc/mermaid.lua"
                                                            (or (getenv "XDG_CONFIG_HOME")
                                                                "~/.config")))
        markdown-fontify-code-blocks-natively t
        markdown-enable-wiki-links nil)
  ;; Prefer xwidget-webkit for in-Emacs rendering when available
  (when (featurep 'xwidget-internal)
    (setq markdown-browse-url-func #'xwidget-webkit-browse-url)))
