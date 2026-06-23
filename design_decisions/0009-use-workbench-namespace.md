# 0009. Use Workbench Namespace

Date: 2026-06-22
Status: Accepted

## Context

Emacs Lisp has a global symbol namespace for functions and variables. Generic
custom names such as `open-terminal`, `project-root`, or `toggle-ai` can collide
with package code or become ambiguous as the configuration grows.

The project is being designed as an Emacs Workbench application rather than a
collection of unrelated snippets.

## Decision

Use `workbench/` as the namespace for custom public commands and variables.

Examples:

```elisp
workbench/open-codex
workbench/open-nvim
workbench/project-notes
workbench/workbench-root
```

Use `workbench--` for private helpers.

Examples:

```elisp
workbench--open-vterm-command
workbench--project-root
```

## Consequences

Custom workbench behavior is easy to identify and search for.

Command discovery through `M-x workbench/` becomes useful.

Function and variable names are longer, but the extra verbosity is acceptable
for clarity and collision avoidance.
