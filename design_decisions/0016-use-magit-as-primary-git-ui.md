# 0016. Use Magit as Primary Git UI

Date: 2026-06-22
Status: Accepted

## Context

The current workflow uses terminal/editor Git tools such as lazygit, diffview,
and gitsigns-style actions. The Emacs Workbench should make Git part of the same
buffer, project, and keybinding environment as editing and file management.

Magit is the standard Emacs Git interface and provides status, staging,
committing, diffs, logs, branches, rebasing, stashing, blame, and other Git
operations through Emacs buffers.

## Decision

Use Magit as the primary Git UI.

Configure Magit and related Git behavior in `doom/modules/tools/git.el`.

Terminal Git and lazygit may remain available through vterm as fallback or
compatibility workflows, but they are not the primary Git interface in the first
version.

## Consequences

Git work can happen inside the Emacs workbench with native buffers and keymaps.

The user will need to learn Magit conventions and transient menus.

Existing lazygit muscle memory remains available through the terminal layer, but
the workbench design will optimize for Magit first.
