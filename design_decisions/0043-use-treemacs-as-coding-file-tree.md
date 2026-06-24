# 0043. Use Treemacs as the Coding-Layout File Tree

Date: 2026-06-24
Status: Accepted

## Context

ADR 0014 defined the coding layout as `Dirvish | Code | AI`, with the left pane
being the Dirvish/Dired file manager.

Refining the workflow against the user's Neovim setup shows two distinct file
tools, not one:

- neo-tree — a persistent in-project tree on the left, used to switch which file
  is being edited
- Yazi/oil — a separate full file manager used to browse between projects

ADR 0042 already places Dirvish as the files-workspace browsing surface (the
Yazi equivalent). Using Dirvish for both the cross-project browser and the
in-project left pane conflates these two roles and does not match the user's
actual habits.

## Decision

The coding-layout left pane is Treemacs, the Emacs equivalent of neo-tree.

Dirvish keeps its role from ADR 0011 and ADR 0042 as the cross-workspace file
browser (Yazi equivalent), living in the files workspace. The coding layout
becomes:

```text
Treemacs | Code | project AI
```

Treemacs in a coding workspace:

- roots its top-level node at the directory opened as the project, even when
  that directory is not a VCS project
- enables follow-mode so it reveals and highlights the active buffer's file,
  matching neo-tree `follow_current_file`
- shows git status and dotfiles
- supports in-tree file management: create, copy, rename, move, delete, open
- uses width 25
- is toggled with `SPC e`; opening a file from it replaces the center buffer

This supersedes the left-pane definition in ADR 0014. The center (code) and
right (AI) panes from ADR 0014 are unchanged.

## Consequences

The in-project tree matches the user's neo-tree muscle memory.

Dirvish and Treemacs have clear, non-overlapping roles: browse between projects
versus navigate within one.

Treemacs becomes a required `:ui` module (already added to `init.el`).

Plain Dired/Dirvish is no longer the in-project coding navigator; any earlier
assumption that the left coding pane is Dirvish is replaced.
