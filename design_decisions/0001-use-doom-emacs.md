# 0001. Use Doom Emacs

Date: 2026-06-22
Status: Accepted

## Context

The Emacs Workbench is intended to be a one stop shop for editing, projects,
Git, files, terminals, notes, AI tools, and compatibility with the existing
Neovim workflow.

Building this from vanilla Emacs would provide maximum architectural ownership,
but would require designing and maintaining package bootstrapping, Evil setup,
completion, project search, UI defaults, language modules, and common workflow
integration before the workbench becomes useful.

The existing Neovim setup is already highly customized, so the Emacs setup
should still allow strong ownership of workflow design and key behavior.

## Decision

Use Doom Emacs as the base framework for the Emacs Workbench.

Doom will provide the framework layer: package management, module selection,
Evil defaults, completion stack, startup behavior, and common integrations.

The Emacs Workbench will provide the application layer: workflow modules,
keymaps, theme conventions, terminal commands, AI integration, project behavior,
and compatibility commands for tools such as Neovim.

## Consequences

The first usable version can be built faster because common editor and IDE
plumbing is supplied by Doom.

The workbench must follow Doom's configuration model, especially `init.el`,
`config.el`, `packages.el`, Doom modules, and `doom sync`.

Some behavior may be hidden behind Doom abstractions, so debugging requires
learning Doom conventions as well as Emacs Lisp.

The project can still keep a clear application architecture by placing personal
behavior in small workflow-oriented modules loaded from Doom's `config.el`.
