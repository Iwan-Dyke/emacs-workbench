;;; tools/formatting.el -*- lexical-binding: t; -*-

;; Formatting via Doom's :editor format module / apheleia (ADR 0018). Format is
;; manual: the +onsave flag is intentionally not enabled, so nothing reformats on
;; save; run it with SPC c f. Python formats with Ruff (ADR 0018); the other
;; languages use the Doom/apheleia defaults (gofmt, stylua, shfmt, yamlfmt,
;; terraform fmt), checked by bin/doctor.

(set-formatter! 'ruff '("ruff" "format" "-") :modes '(python-mode python-ts-mode))
