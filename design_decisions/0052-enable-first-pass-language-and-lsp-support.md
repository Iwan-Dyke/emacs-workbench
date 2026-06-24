# 0052. Enable First-Pass Language and LSP Support

Date: 2026-06-24
Status: Accepted

## Context

ADRs 0017 (lsp-mode), 0018 (Doom format module), and 0029 (language scope)
decided how coding support should work, but `init.el` enabled none of it: no
`:lang`, `:tools lsp`, `:checkers`, or `:editor format` modules. The coding
shell (workspaces, tree, AI panes, navigation) existed around a vanilla editor.

## Decision

Enable the decided support through Doom modules and two thin config files.

- `init.el`: `:checkers syntax`; `:tools lookup lsp (docker +lsp)
  (terraform +lsp)`; `:editor format snippets`; `:lang emacs-lisp
  (python +lsp +pyright) (go +lsp) (sh +lsp) (lua +lsp) (yaml +lsp) markdown
  org`.
- SQL has no Doom `:lang` module, so it uses Emacs' built-in `sql-mode`, with
  lsp attached only when the `sqls` server is present.
- `tools/languages.el`: minimal lsp-mode behavior — guess the project root
  instead of prompting, do not offer to download servers (they are managed
  externally), hide the breadcrumb.
- `tools/formatting.el`: format is manual (the `+onsave` flag is not enabled);
  Python formats with Ruff via `set-formatter!`.
- `system/keybindings.el`: `SPC c f` formats; lsp and lookup provide the rest of
  the `SPC c` code surface.
- `bin/doctor`: check each language server and formatter.

Two additions beyond the original ADRs: `:editor snippets` (lsp completion
expects yasnippet) and `:tools lookup` (go-to-definition and references).

## Consequences

Opening a file now gets completion, diagnostics, and navigation where a server
exists; seven servers and four formatters are already present.

Language servers and formatters are external dependencies. `bin/doctor` flags
the missing ones — currently `ruff`, the `terraform` CLI, and `sqls` — and the
workbench works without them, just without that language's LSP or formatter.

lsp-mode is heavier than Eglot (noted in ADR 0017); if it becomes a burden, that
ADR already leaves the door open to revisit.
