# 0053. Use a Top-Level Install Entrypoint

Date: 2026-06-25
Status: Accepted

## Context

The workbench is meant to be installable from scratch on a new laptop with a
small number of obvious commands. The current project already has
`bin/install`, but a new user or future self cloning the repository should not
have to inspect `bin/` before knowing how to start.

The expected first-run flow should be close to:

```bash
git clone <repo-url> ~/homelab/projects/emacs-workbench
cd ~/homelab/projects/emacs-workbench
./install.sh
```

The installer may eventually need to check or install host prerequisites, install
Doom when missing, link `~/.config/doom` to this repository, run Doom sync, and
report remaining optional tool gaps. Those actions are mutating, so they belong
in install/sync commands, not in the read-only doctor command (ADR 0031).

## Decision

Provide a top-level `install.sh` as the primary human-facing install entrypoint.

Keep `bin/install` as the implementation script and have `install.sh` delegate
to it. This preserves the existing script boundary while making the first-run
command discoverable from the repository root.

The install flow should be:

1. preflight checks
2. clear summary of intended changes
3. safe setup of missing required pieces where supported
4. Doom config symlink setup
5. Doom sync
6. doctor-style health report
7. next-command guidance for launching the workbench

The installer must be idempotent. Re-running it should repair or confirm the
expected setup without duplicating files, overwriting unrelated user config, or
silently changing profile behavior.

When an existing `~/.emacs.d` or `~/.config/doom` does not belong to this
workbench, the default behavior should be to stop with a clear message. Backup
or takeover behavior should require an explicit future flag rather than happen
implicitly.

## Consequences

The first install command is easy to remember and visible at the repository root.

`bin/install` remains the place for setup logic, so the project does not gain
two competing installers.

The installer becomes more responsible than the current skeleton and therefore
needs careful guardrails, clear output, and shell checks.

`bin/doctor` remains safe to run at any time because it does not install,
repair, link, sync, or mutate user state.
