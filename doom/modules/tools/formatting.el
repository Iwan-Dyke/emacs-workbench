;;; tools/formatting.el -*- lexical-binding: t; -*-

(set-formatter! 'ruff '("ruff" "format" "-") :modes '(python-mode python-ts-mode))
