# 0003. Build Full Workbench Project

Date: 2026-06-22
Status: Accepted

## Context

The project is intended to become a personal Emacs-based workbench, not only a
small Doom configuration. It should support the full application lifecycle:
design, configuration, installation, sync, health checks, documentation, and
eventual dotfiles integration.

A Doom-config-only project would be simpler, but would leave installation,
dependency checks, and workflow documentation outside the project.

## Decision

Make `emacs-workbench` a full workbench project.

The repository will contain the Doom user configuration, helper scripts,
documentation, and design decisions.

Initial structure:

```text
emacs-workbench/
  README.md
  design_decisions/
  bin/
    install
    sync
    doctor
  doom/
    init.el
    config.el
    packages.el
    modules/
  docs/
```

## Consequences

The repository can be treated as the source of truth for the workbench
application, including setup and operational checks.

Helper scripts must stay small, idempotent, and defer to Doom's own tooling
where possible.

The project has more moving parts than a plain Doom config, but the structure
better matches the goal of building a complete personal workbench.
