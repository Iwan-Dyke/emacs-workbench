# 0018. Use Doom Format Module First

Date: 2026-06-22
Status: Accepted

## Context

The current Neovim setup uses explicit external formatters:

```text
Lua        stylua
Python     ruff organize imports + ruff format
Go         gofmt
Terraform  terraform fmt
Shell      shfmt
YAML       yamlfmt
```

The Emacs Workbench should preserve that intent while staying aligned with Doom
where practical.

## Decision

Use Doom's `:editor format` module as the first-pass formatting integration.

Document and check for the intended external formatters, including Ruff for
Python formatting and lint/fix workflows.

Keep formatter configuration in:

```text
doom/modules/tools/formatting.el
```

Use a workbench keybinding for formatting through the central keybinding file.

## Consequences

The first pass follows Doom's standard formatting path instead of adding a
separate formatter framework immediately.

Some language-specific behavior, especially Ruff import organization, may need
explicit configuration.

If Doom's formatting path is too implicit or awkward, a later decision can
evaluate using a more explicit formatter package such as Apheleia.
