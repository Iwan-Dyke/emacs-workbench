# 0054. Create Profile Launch Commands During Install

Date: 2026-06-25
Status: Accepted

## Context

The workbench already has a profile-aware launcher (`bin/workbench`) and
separate profile daemons (`workbench-personal`, `workbench-work`) from ADRs
0019, 0022, and 0023. That launcher is correct internally, but it is still a
project-local command unless the user adds it to their shell path.

The desired everyday UX is simpler:

```bash
startup
startup-work
```

Those commands should open the different workbench profiles without requiring
the user to remember daemon names or pass profile arguments. The profile daemon
model remains an implementation detail.

Shell aliases would work for one shell, but they are harder to keep idempotent
across Bash, Zsh, Fish, login shells, graphical launchers, and future machines.
Small wrapper scripts in a user-local bin directory are easier to inspect,
replace, and call from any shell.

## Decision

During installation, create user-facing launch commands that delegate to
`bin/workbench`.

Initial commands:

```text
startup       -> <repo>/bin/workbench personal
startup-work  -> <repo>/bin/workbench work
workbench     -> <repo>/bin/workbench
```

Install these as small executable wrapper scripts in `~/.local/bin` by default.
The installer should check whether `~/.local/bin` is on `PATH` and print a clear
next step if it is not.

Do not edit shell startup files automatically in the first implementation. If
PATH setup is needed, print the exact line the user can add manually.

The wrappers should be idempotent and owned by this workbench. If a target
command already exists and does not point at this repository, the installer
should stop or warn clearly instead of overwriting it.

Keep `bin/workbench` as the canonical lifecycle interface for explicit commands:

```bash
workbench personal
workbench work
workbench stop personal
workbench restart work
```

## Consequences

Daily startup is short and memorable while the implementation keeps the existing
profile-aware daemon launcher.

The user can start personal and work contexts without knowing or typing the
profile daemon names.

Wrapper scripts work across shells better than aliases and avoid mutating shell
configuration during installation.

There is a possible naming conflict with an existing `startup` command on a
machine. The installer must detect that and avoid overwriting unrelated commands.
