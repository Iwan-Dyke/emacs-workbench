# 0002. Use Integrated Workbench Architecture

Date: 2026-06-22
Status: Accepted

## Context

The goal is to make Emacs the main working environment rather than only a text
editor. The current workflow uses separate tools for editing, terminal
sessions, file management, Git, search, notebooks, and AI CLIs.

Those tools work well individually, but they create context switching and
separate state across Neovim, tmux, Yazi, lazygit, shell sessions, and editor
plugins.

The Emacs Workbench should consolidate the workflows where integration matters,
while still allowing terminal tools and Neovim to remain available during the
migration.

## Decision

Use an Integrated Workbench architecture.

Doom Emacs provides the framework runtime. The workbench config provides a
single application layer for editing, projects, Git, files, terminals, notes,
AI tools, and compatibility commands.

Personal behavior will be split into small modules organized around workflow
areas rather than placed directly into one large `config.el`.

Initial workflow areas:

- interface
- navigation
- editing
- coding
- operations
- knowledge
- AI
- compatibility

## Consequences

Emacs becomes the shared runtime for project context, buffers, keymaps, themes,
commands, and workflow state.

The configuration remains easier to maintain than a single large `config.el`
because each module has a clear responsibility.

This design intentionally accepts a single integrated runtime. A failure in the
Emacs config can affect the whole workbench, so changes should stay small and be
verified incrementally.

Some tools should remain external when process isolation matters. Neovim, shell
tools, and AI CLIs can run inside Emacs terminals instead of being immediately
replaced by native Emacs behavior.
