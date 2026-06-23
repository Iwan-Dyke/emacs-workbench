# 0017. Use lsp-mode for Coding Support

Date: 2026-06-22
Status: Accepted

## Context

The workbench needs coding features such as go to definition, hover
documentation, rename, code actions, diagnostics, references, and completion.

The current Neovim setup uses LSP servers for Python, Go, Terraform, Lua, Bash,
YAML, Dockerfile, and SQL.

In Emacs, the main LSP choices are `lsp-mode` and Eglot. Eglot is simpler and
built into modern Emacs, while `lsp-mode` is more feature-rich and commonly
used with Doom's language modules.

## Decision

Use Doom's `:tools lsp` path with `lsp-mode` for the first-pass workbench.

Keep LSP configuration minimal at first and place language/tool behavior in:

```text
doom/modules/tools/languages.el
```

Coding workflow commands should live in:

```text
doom/modules/workflows/coding.el
```

## Consequences

The first-pass workbench gets the richer LSP feature set and follows Doom's
well-supported path.

`lsp-mode` has more moving parts and may require more tuning than Eglot.

If it feels too heavy or hard to maintain, a later decision can evaluate moving
some or all language support to Eglot.
