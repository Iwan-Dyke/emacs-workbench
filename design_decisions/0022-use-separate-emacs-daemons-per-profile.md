# 0022. Use Separate Emacs Daemons Per Profile

Date: 2026-06-22
Status: Accepted

## Context

The workbench supports personal and work profiles with different project roots,
Org settings, AI defaults, and private overrides.

Using one shared Emacs daemon for all profiles would be simpler, but it could
mix personal and work buffers, notes, terminal sessions, and AI defaults in one
process.

## Decision

Use a separate Emacs daemon per workbench profile.

Examples:

```text
workbench personal -> workbench-personal daemon
workbench work     -> workbench-work daemon
```

The launcher should hide the daemon details from normal use.

## Consequences

Personal and work sessions stay isolated.

The active profile is fixed for each daemon, which avoids confusing profile
switches inside a running Emacs process.

Running both profiles at once uses more memory and starts separate Emacs
processes, but the isolation is worth the cost for this workbench.
