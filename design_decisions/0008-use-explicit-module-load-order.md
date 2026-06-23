# 0008. Use Explicit Module Load Order

Date: 2026-06-22
Status: Accepted

## Context

The workbench config is split into modules under `system/`, `tools/`, and
`workflows/`. Those modules need to be loaded from Doom's `config.el`.

An automatic loader could discover and load module files, but that would hide
the startup order and make filename ordering or loader behavior part of the
architecture.

Ease of understanding is a primary goal.

## Decision

Use explicit `load!` calls in `config.el`.

The load order should be manual and readable:

```text
1. system core
2. system interface
3. tools
4. workflows
5. system keybindings
```

Do not auto-discover module files.

Use Doom lazy-loading patterns inside modules for expensive package and runtime
behavior. Loading a module file should be cheap; loading external packages,
starting tools, scanning projects, and opening terminals should happen only when
needed.

## Consequences

The boot sequence is visible in one place, which makes the config easier to
understand and debug.

Adding or removing a module requires editing `config.el`, but that cost is small
and keeps startup behavior explicit.

Startup performance depends on keeping top-level module code lightweight.
Package-specific configuration should use Doom patterns such as `after!`,
`use-package!`, hooks, and command autoloads instead of eager `require` calls.
