# 0005. Build Full First-Pass Workbench

Date: 2026-06-22
Status: Accepted

## Context

The project is being designed as a complete personal workbench rather than a
minimal editor configuration. The first version should express the intended
application shape, even if individual workflows are refined later.

A minimal first pass would reduce initial complexity, but it would delay
important architecture decisions around terminals, AI tools, language support,
Org, health checks, and documentation.

## Decision

Build a full first-pass workbench.

The first implementation should include:

- Doom install/link support
- Doom module selection
- workflow-oriented user modules
- Evil editing
- completion and project navigation
- Git workflow
- file management
- terminals
- Neovim compatibility
- AI CLI terminals
- LSP and language support
- formatting
- Org notes/tasks/literate workflow foundation
- theme layer
- doctor checks
- workflow and keymap documentation

## Consequences

The initial build will take longer than a minimal config, but it will validate
the real target architecture earlier.

The implementation must stay incremental and verify each layer before adding the
next one.

Some areas may start as thin wrappers over Doom defaults, but their module
boundaries should still exist from the beginning so the workbench grows in the
intended shape.
