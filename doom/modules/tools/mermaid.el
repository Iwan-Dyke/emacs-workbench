;;; tools/mermaid.el -*- lexical-binding: t; -*-

;; Mermaid diagram rendering via ob-mermaid (org-babel) and mermaid-mode.
;; Requires: mmdc (npm install -g @mermaid-js/mermaid-cli)

(defvar ob-mermaid-cli-path)
(defvar ob-mermaid-output)
(defvar mermaid-mmdc-location)
(defvar mermaid-output-format)

;;; ── ob-mermaid (org-babel integration) ─────────────────────────────────────

(defvar org-babel-load-languages)

(after! org
  (add-to-list 'org-babel-load-languages '(mermaid . t) t)
  (org-babel-do-load-languages 'org-babel-load-languages org-babel-load-languages))

(after! ob-mermaid
  ;; Use mmdc from PATH; override if installed elsewhere.
  (setq ob-mermaid-cli-path (or (executable-find "mmdc") "mmdc"))
  ;; Default to PNG output for inline display in org buffers.
  (setq ob-mermaid-output "png"))

;;; ── mermaid-mode (standalone .mmd editing) ─────────────────────────────────

(after! mermaid-mode
  (setq mermaid-mmdc-location (or (executable-find "mmdc") "mmdc")
        mermaid-output-format ".png"))

(provide 'workbench-mermaid)
