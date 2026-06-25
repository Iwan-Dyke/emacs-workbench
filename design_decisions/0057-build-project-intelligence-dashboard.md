# 0057. Build Project Intelligence Dashboard

Date: 2026-06-25
Status: Accepted

## Context

ADR 0045 deferred the rich project dashboard. The current project workspace
placeholder shows only the project name and path, which is not enough context
when opening a repository from Dirvish.

The desired workflow is closer to opening a project from Yazi into Neovim and
immediately understanding what kind of repository it is, what state it is in,
and how to start working on it.

Doom's built-in dashboard remains useful as the global startup/fallback screen,
but it is not the right shape for a specific project. It is global, centered on
the fallback buffer, and designed around startup actions and last-directory
memory rather than a selected project directory.

## Decision

Replace the placeholder project buffer with a custom workbench project
intelligence dashboard.

The dashboard should be a read-only project-specific buffer opened by
`workbench/open-project-dashboard` after `SPC p o` creates or switches to the
project workspace.

First-pass dashboard sections:

```text
Overview
  project name
  project path
  detected project type

Git
  current branch
  clean/dirty/untracked counts
  upstream remote when configured
  ahead/behind counts when upstream exists
  last commit hash, subject, author, and date

Languages
  top languages by tracked files or approximate line counts
  percentage breakdown

Commands
  detected task entrypoints from justfile, Makefile, package.json, go.mod,
  pyproject.toml, Cargo.toml, and similar project files

Recent
  recent commits
  changed files in the current worktree

Actions
  open files
  search project
  open Magit
  open terminal
  toggle project AI
  open README when present
```

Data collection should be local and dependency-light:

- use `git -C <dir>` for Git state
- use `git ls-files` in Git repositories
- fall back to bounded directory scanning outside Git repositories
- infer languages from file extensions first
- avoid generated and dependency directories such as `.git`, `node_modules`,
  `.venv`, `vendor`, `dist`, and `build`

Render the first version as a `special-mode` buffer with simple text sections,
keyboard bindings, and text buttons for actions. Do not implement live refresh
initially; rebuild the dashboard when it is opened and add a manual refresh
command if needed.

## Consequences

Opening a project workspace becomes useful before opening a file.

The dashboard answers the immediate questions:

- What is this project?
- What stack does it use?
- Is the repository clean?
- Is it ahead or behind its upstream?
- What commands are likely available?
- What should I open next?

Keeping the dashboard custom avoids fighting Doom's global dashboard design.

The first language breakdown will be approximate. A later version can use
external tools such as `tokei`, `scc`, or GitHub Linguist if they prove worth
the dependency.

Live monitoring, stored test status, and multi-repo operations remain out of
scope for this ADR. ADR 0040 still covers the separate future multi-repository
dashboard.
