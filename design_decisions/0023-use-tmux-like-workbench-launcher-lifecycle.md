# 0023. Use tmux-Like Workbench Launcher Lifecycle

Date: 2026-06-22
Status: Accepted

## Context

The workbench will use separate Emacs daemons per profile. An Emacs daemon can
keep running after its visible frame is closed, allowing the user to reconnect
later.

This is similar to the tmux model where a session can continue running in the
background and the user can attach to it later.

## Decision

Make `bin/workbench` provide tmux-like lifecycle behavior.

Normal launch commands attach to an existing daemon or start one if needed:

```bash
workbench personal
workbench work
```

Lifecycle commands manage profile daemons:

```bash
workbench stop personal
workbench stop work
workbench restart personal
workbench restart work
```

The launcher should hide daemon names from normal use.

Closing a visible Emacs frame should leave the profile daemon running. Ending a
profile session should require an explicit lifecycle command such as:

```bash
workbench stop work
```

## Consequences

Closing an Emacs frame does not have to end the workbench session.

The user can reconnect to a profile-specific workbench session later.

Accidental frame closure is less destructive because it does not stop the
underlying profile daemon.

The launcher becomes slightly more complex, but it gives the workbench a clear
session model that matches the desired tmux-like behavior.

Long-running terminal workloads may still be better suited to tmux if they must
survive independently of Emacs terminal buffers.
