# 0019. Use Profile-Aware Workbench Launcher

Date: 2026-06-22
Status: Accepted

## Context

The workbench needs to support personal and work contexts. Those contexts may
need different project roots, Org files, AI command defaults, and workflow
settings.

Secrets, tokens, credentials, and machine-specific environment setup should not
live in the Emacs config or the repository.

## Decision

Provide a `bin/workbench` launcher that accepts an optional profile argument.

Examples:

```bash
workbench
workbench personal
workbench work
```

The launcher sets `WORKBENCH_PROFILE` before starting Emacs or `emacsclient`.

Default profile:

```text
personal
```

Emacs reads `WORKBENCH_PROFILE` and uses it for workflow settings only.

Profile settings may include:

- project roots
- Org directories and agenda files
- default AI command choices
- workbench behavior flags

Profile settings must not include secrets.

## Consequences

The user can choose personal or work context at launch time with a simple
command.

The shell remains responsible for secrets and machine environment.

Emacs remains responsible for profile-specific workflow behavior.

The first implementation needs a small launcher script and a profile loader in
the Doom config.
