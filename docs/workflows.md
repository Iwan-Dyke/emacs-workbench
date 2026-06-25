# Workflows

This workbench is a Doom Emacs setup organized around a small number of
repeatable workspaces.

## Startup

Launch the personal profile:

```bash
startup
```

Launch the work profile:

```bash
startup-work
```

Each profile runs its own Emacs daemon. A fresh graphical frame opens the startup
workspace set once per Emacs process:

- the original Doom dashboard workspace
- a `files` workspace
- an `ai` workspace running the profile default AI tool

You can rebuild the startup workspaces manually with `SPC w s`.

## Files

The `files` workspace opens full-frame Dirvish with a file list and preview pane.
When you leave and return to that workspace, the workbench rebuilds Dirvish at the
last directory and file you visited.

Use `SPC f m` to open the file manager from the current project context.

## Projects

Open a project workspace with `SPC p o`.

From Dired or Dirvish, this opens the selected directory as a project workspace.
From any other buffer, it prompts for a directory.

The first-pass project workspace lands on a project dashboard. From there:

- use `SPC e` to toggle the Treemacs project tree
- use `SPC g g` to open Magit status
- use `SPC t c`, `SPC t k`, or `SPC t x` to toggle a project AI pane

## Terminals

Use `SPC t t` to open a terminal workspace. Project AI panes are also vterm
buffers, docked on the right side of the current project layout.

Window movement uses `C-h`, `C-j`, `C-k`, and `C-l`, including inside vterm, so a
terminal pane should not trap focus.

## AI

There are two AI scopes:

- global/session AI runs full-window in the `ai` workspace
- project AI runs as a right-side pane in the current project layout

Use `SPC a a` to open the profile default global AI workspace. Use `SPC a p` to
toggle the profile default project AI pane.
