# 0035. Use Simple AI Buffer Names

Date: 2026-06-23
Status: Accepted

## Context

The workbench supports separate personal and work daemons, so profile isolation
already happens at the Emacs process level. AI terminals also have two scopes:
global/session AI and project/layout AI.

Buffer names should be easy to read and switch to without over-encoding context.

## Decision

Use simple AI buffer names in the first pass.

Global/session AI buffers:

```text
*kiro*
*claude*
*codex*
```

Project/layout AI buffers:

```text
*project-kiro*
*project-claude*
*project-codex*
```

Do not include the profile name in buffer names because profiles run in separate
daemons.

Manual or richer buffer naming can be added later if simple names become
ambiguous.

## Consequences

AI buffers are easy to recognize and switch to.

If multiple project-specific sessions are needed at the same time in one
profile daemon, the naming scheme may need to evolve.

The first pass prioritizes simplicity over encoding all context in buffer names.
