# 0040. Add Multi-Repo Operations Dashboard Later

Date: 2026-06-23
Status: Accepted

## Context

The user has an existing workflow that scans multiple Git repositories and
reports whether each repository is dirty, ahead, behind, or otherwise needs
attention.

Magit is the primary Git UI for working inside one repository, but it does not
by itself provide a custom overview of all personal and work repositories in
one place.

The workbench should eventually support operational awareness across many repos
without replacing Magit for detailed per-repo Git work.

## Decision

Add a multi-repo operations dashboard later.

The first version should scan configured profile project roots for Git
repositories and show a read-only Emacs buffer with repository status.

Example shape:

```text
repo             branch   state
emacs-workbench main     dirty, ahead 12
dotfiles        main     clean
work-api        develop  behind 3
infra           main     dirty, ahead 1, behind 2
```

Rows should eventually open Magit for the selected repository.

This feature should live in a workflow module, likely:

```text
doom/modules/workflows/operations.el
```

## Consequences

The workbench can provide tmux/session-level operational awareness across many
repositories while keeping Magit as the detailed Git interface.

The first implementation can start with synchronous shell commands and a simple
read-only buffer, then become asynchronous and filterable later if needed.

This should wait until the basic Magit entrypoint and project/profile structure
are in place.
