# 0036. Include Workbench Usage Docs

Date: 2026-06-23
Status: Accepted

## Context

The workbench is a custom Emacs application with profile-aware launch behavior,
separate daemons, a command-driven coding layout, custom keybindings, AI
terminal scopes, Dirvish file management, Magit Git workflow, and an Org/org-roam
knowledge graph.

Those workflows are too specific to rely only on Doom or package documentation.

## Decision

Include user-facing documentation in the first pass.

Initial docs:

```text
README.md
docs/workflows.md
docs/keybindings.md
docs/profiles.md
docs/knowledge.md
```

The README should explain what the project is and how to install, launch, sync,
and diagnose it.

The docs directory should explain how to use the workbench workflows.

## Consequences

The workbench remains easier to relearn and maintain.

Docs add some maintenance cost, but they are important because the project is a
personal application rather than a generic Doom config.

Design rationale still belongs in ADRs under `design_decisions/`; usage belongs
in the README and `docs/`.
