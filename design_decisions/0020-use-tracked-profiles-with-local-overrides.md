# 0020. Use Tracked Profiles With Local Overrides

Date: 2026-06-22
Status: Accepted

## Context

The workbench supports personal and work profiles. The main workflow defaults
should live in the repository so the workbench remains a one stop shop.

Some settings are machine-specific or private and must not be committed, such as
local paths, private keys, credentials, tokens, or machine-only command
overrides.

## Decision

Store tracked profile defaults in the workbench repo:

```text
doom/profiles/personal.el
doom/profiles/work.el
```

Support an untracked local override file:

```text
doom/profiles/local.el
```

Support a separate untracked secrets file when absolutely needed:

```text
doom/profiles/secrets.el
```

Provide a tracked example:

```text
doom/profiles/local.el.example
doom/profiles/secrets.el.example
```

Load profile configuration in this order:

```text
1. selected tracked profile: personal.el or work.el
2. optional local.el override if present
3. optional secrets.el override if present
```

`local.el` and `secrets.el` must be ignored by Git.

## Consequences

Shared personal/work workflow settings are versioned with the workbench.

Private or machine-specific settings can override the tracked defaults without
being committed.

Sensitive values have a separate file from ordinary local settings, which makes
the boundary easier to audit.

The config loader must tolerate missing local overrides.

Secrets should still preferably come from the shell environment or secure files;
`secrets.el` is an escape hatch, not the primary secrets manager.
