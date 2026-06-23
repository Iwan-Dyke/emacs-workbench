# 0006. Use System, Tools, and Workflows Module Structure

Date: 2026-06-22
Status: Accepted

## Context

The workbench needs clear module boundaries. Pure tool-based modules are easy
to debug, but do not capture user workflows well. Pure workflow-based modules
match the goal of a one stop shop, but make shared tools such as terminals,
project search, file management, and keymaps harder to place.

The module names should be easy to understand and should avoid abstract product
or enterprise terminology.

## Decision

Organize personal Doom modules under three plain categories:

```text
doom/modules/
  system/
  tools/
  workflows/
```

Use this ownership rule:

```text
system    = how Emacs behaves globally
tools     = how individual reusable tools are configured
workflows = how tools are combined for daily work
```

Initial module layout:

```text
doom/modules/
  system/
    core.el
    interface.el
    keybindings.el
  tools/
    completion.el
    projects.el
    files.el
    git.el
    terminals.el
    languages.el
    formatting.el
    org.el
  workflows/
    coding.el
    operations.el
    knowledge.el
    ai.el
    compatibility.el
```

Examples:

- generic `vterm` setup belongs in `tools/terminals.el`
- Claude, Codex, and Kiro terminal commands belong in `workflows/ai.el`
- generic Magit setup belongs in `tools/git.el`
- repo review commands belong in `workflows/operations.el`
- theme, fonts, and modeline belong in `system/interface.el`

## Consequences

Shared tools have one clear home, which reduces ambiguity when debugging or
changing package behavior.

Workflow modules can still express the user-facing workbench behavior without
owning low-level package configuration.

The structure has more files than a single `config.el`, but the names and
ownership rule should make it easier to understand and maintain.
