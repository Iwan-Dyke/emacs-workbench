# 0037. Use Doom Workspaces as tmux-like Tabs

Date: 2026-06-23
Status: Accepted

## Context

The workbench is intended to feel familiar to a tmux-based workflow. The user
wants tabs for broader working contexts, not only buffers or panes.

Emacs has several related concepts:

- buffers for open files, terminals, and tool views
- windows for panes inside a frame
- frames for OS-level windows
- tabs or workspaces for groups of buffers and window layouts

Plain Emacs `tab-bar-mode` could provide frame-level tabs, but the project is
built on Doom Emacs and should prefer Doom-native conventions where they fit.

## Decision

Use Doom workspaces as the tmux-like tab layer.

The working model is:

```text
tmux session -> Emacs daemon/profile
tmux window  -> Doom workspace
tmux pane    -> Emacs window
terminal app -> Emacs buffer
```

Example workspaces may include:

```text
code
notes
git
ai
```

The first implementation should enable Doom's `:ui workspaces` module and use
Doom's built-in workspace commands before adding custom workbench bindings.

## Consequences

Workspaces give the workbench a familiar tmux-like way to separate broad
contexts while staying inside one Emacs profile daemon.

Each workspace can hold its own window layout, such as a coding workspace with
files, code, and AI panes.

Buffers still exist globally underneath the workspace model, so this is not a
perfect one-to-one tmux clone. The workbench should treat workspaces as context
tabs, not as hard isolation boundaries.
