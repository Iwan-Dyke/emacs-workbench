# 0031. Make Doctor Read-Only

Date: 2026-06-23
Status: Accepted

## Context

The workbench will include helper scripts for installation, syncing, launching,
and health checks. A doctor command is useful for diagnosing missing
dependencies and configuration problems.

Health checks are easier to trust when they do not modify the system.

## Decision

Make `bin/doctor` read-only.

It should check and report status, but it must not install packages, edit files,
change symlinks, run migrations, or modify Doom/Emacs state.

Installation and repair behavior belongs in `bin/install`, `bin/sync`, or
explicit user commands.

## Consequences

`bin/doctor` can be run safely at any time.

Missing dependencies and configuration issues must be fixed separately.

The doctor script should produce clear output that distinguishes missing tools,
misconfiguration, and optional unavailable features.
