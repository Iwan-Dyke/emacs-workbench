# 0007. Centralize Custom Keybindings

Date: 2026-06-22
Status: Accepted

## Context

The workbench should be easy to understand and operate through a coherent
keyboard interface. If each module defines its own custom keybindings, behavior
stays close to the tool configuration, but the overall interface becomes harder
to inspect and conflicts are easier to introduce.

Keybindings are part of the user interface, so they should be designed as a
whole.

## Decision

Use `doom/modules/system/keybindings.el` as the owner of custom workbench
keybindings.

Other modules own behavior, commands, and tool configuration. The keybindings
module maps keys to those commands.

Example ownership:

```text
workflows/ai.el
  defines id/open-codex

tools/terminals.el
  configures vterm

system/keybindings.el
  maps the chosen keybinding to id/open-codex
```

All custom global keybindings should live in this one file for the first
version. Organize `keybindings.el` by user-facing key groups such as files,
buffers, projects, Git, terminals, code, notes, AI, compatibility, windows, and
session commands.

## Consequences

The complete custom keyboard interface can be inspected in one file.

Conflicts should be easier to spot because leader mappings are designed in one
place.

Command names must be clear because keybindings are separated from command
definitions.

The file may become large, but moving mappings later is straightforward. Start
centralized for ease of understanding, then split only if the file becomes hard
to scan.

Module-local keymaps may still be used when they are tightly scoped to a major
mode or package-specific transient state, but global workbench keybindings
belong in `system/keybindings.el`.
