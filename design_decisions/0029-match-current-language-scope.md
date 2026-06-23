# 0029. Match Current Language Scope

Date: 2026-06-22
Status: Accepted

## Context

The current Neovim setup supports Python, Go, Terraform, SQL, Bash, YAML,
Dockerfile, Lua, Markdown, and notebook-oriented workflows. The Emacs Workbench
should cover the same daily development surface while also supporting Emacs Lisp
and Org.

## Decision

First-pass language support should include:

```text
Python
Go
Terraform
SQL
Bash/Shell
YAML
Dockerfile
Lua
Markdown
Org
Emacs Lisp
```

Configure language and LSP behavior in:

```text
doom/modules/tools/languages.el
```

Configure formatting behavior in:

```text
doom/modules/tools/formatting.el
```

## Consequences

The workbench can cover the same broad coding surface as the current Neovim
config.

Doctor checks should validate the important language tools and formatters.

Notebook execution remains a separate concern and can continue through Neovim
compatibility or Org/Jupyter work in a later phase.
