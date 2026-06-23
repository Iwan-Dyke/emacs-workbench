# 0034. Use Global and Project AI Scopes

Date: 2026-06-23
Status: Accepted

## Context

The current workflow uses AI tools at two scopes.

At the tmux/session level, Kiro and Claude can run as full-screen terminal
windows for broader work-session conversations. Inside Neovim, Kiro can also run
as a project/editor-scoped vertical terminal pane beside the code.

The Emacs Workbench should preserve this distinction instead of forcing all AI
use into one terminal.

## Decision

Support two AI scopes:

```text
global/session AI
project/layout AI
```

Global/session AI terminals are reusable profile-level vterm buffers, suitable
for full-window or workspace-level interaction.

Project/layout AI is the right-side AI pane in the command-driven coding layout:

```text
Dirvish | Code | profile default AI
```

The profile default AI controls the project/layout AI pane:

```text
personal -> Codex
work     -> Kiro
```

Explicit commands should still exist for Codex, Kiro, and Claude.

## Consequences

The workbench preserves the current distinction between broad session AI and
project-specific code-adjacent AI.

AI commands need clear names and buffer naming so global and project AI sessions
do not get confused.

All first-pass AI sessions run through `vterm`.
