# 0032. Make Sync Focused Doom Wrapper

Date: 2026-06-23
Status: Accepted

## Context

The workbench includes multiple helper scripts with different responsibilities:
installation, syncing Doom state, health checks, and launching profile sessions.

Combining those responsibilities would make commands harder to predict.

## Decision

Make `bin/sync` a focused wrapper around Doom sync.

It should:

- verify that the Doom command exists
- run `doom sync`

It should not run the full doctor checks automatically and should not install or
repair missing dependencies.

Script responsibility boundaries:

```text
bin/install   setup and linking
bin/sync      Doom sync
bin/doctor    read-only health checks
bin/workbench profile daemon launch/lifecycle
```

## Consequences

`bin/sync` remains fast, predictable, and easy to understand.

Users can run `bin/doctor` separately when they want a full health check.

Failures from optional tools do not block ordinary Doom sync unless Doom itself
requires them.
