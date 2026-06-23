# 0041. Use Dashboard to Dirvish Project Workflow First

Date: 2026-06-23
Status: Accepted

## Context

The workbench should support a coding workflow that feels close to the user's
current Neovim, Yazi, tmux, and AI terminal setup.

The familiar morning flow is visual and exploratory:

```text
open session -> browse files/projects -> enter a project -> start coding
```

For the Emacs Workbench, the equivalent tools are:

```text
Doom dashboard -> Doom workspace -> Dirvish/Dired -> project coding workspace
```

Other options exist, including command-first project switching, restoring the
last session, creating a default set of workspaces at startup, opening from a
multi-repo operations dashboard, or starting from a terminal. Those may be
useful later, but they are not the closest first-pass match to the user's
existing workflow.

## Decision

Use a dashboard-to-Dirvish project workflow as the first coding workflow.

The intended first-pass flow is:

```text
1. Open the workbench.
2. Land on the Doom dashboard.
3. Switch to or create a files workspace.
4. Open Dirvish.
5. Browse to a project directory.
6. Explicitly open that directory as a workbench coding workspace.
7. Start coding with files, Git, terminal, and AI available through leader keys.
```

Do not force the full coding layout at startup.

Do not override Dirvish/Dired Enter behavior in the first pass. Enter should
continue to mean the normal file-manager action. Opening a directory as a
coding workspace should be an explicit workbench command or keybinding.

## Consequences

The first coding workflow remains close to the user's current Yazi-to-Neovim
habit while still using Emacs-native concepts.

The workbench can grow a coding workspace command without making startup heavy
or surprising.

Fast project switching, automatic workspace creation, last-session restore, and
multi-repo dashboard entrypoints remain future workflow options.
