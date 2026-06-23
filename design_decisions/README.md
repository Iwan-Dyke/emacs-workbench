# Design Decisions

This directory stores architecture decision records for the Emacs Workbench.

Use ADRs for decisions that are expensive to rediscover later: architecture,
framework choice, deployment model, module boundaries, and major workflow
tradeoffs.

## Naming

Use numbered, kebab-case filenames:

```text
0001-use-doom-emacs.md
0002-use-integrated-workbench-architecture.md
0003-develop-outside-dotfiles-first.md
```

## Format

Each ADR should stay short and use this structure:

```markdown
# NNNN. Title

Date: YYYY-MM-DD
Status: Proposed | Accepted | Superseded

## Context

What problem are we solving? What constraints matter?

## Decision

What did we choose?

## Consequences

What gets better, what gets worse, and what follow-up work exists?
```

Prefer concrete tradeoffs over general preference. If a decision changes, add a
new ADR that supersedes the old one instead of rewriting history.
