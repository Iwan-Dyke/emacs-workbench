# Emacs Workbench

Personal Doom Emacs workbench for editing, projects, Git, files, terminals,
notes, AI tools, and compatibility workflows.

## Structure

- `doom/` contains the Doom Emacs user config.
- `doom/modules/` contains small workbench modules.
- `doom/profiles/` contains tracked profile defaults and local override
  examples.
- `bin/doctor` checks local setup without changing anything.
- `bin/sync` runs `doom sync`.
- `bin/workbench` launches and manages profile-specific Emacs daemons.
- `justfile` contains common project commands.
- `design_decisions/` contains ADRs explaining project decisions.

## Current Status

This project is in first-pass implementation.

Working so far:

- Doom config symlink/install skeleton
- read-only doctor script
- focused sync wrapper
- profile-specific personal/work daemons
- Doom workspaces
- startup workspaces (files browser + default AI agent)
- project/file navigation entrypoints
- Magit project status entrypoint
- Dirvish/Dired file-manager entrypoint
- tmux-like terminal workspaces
- profile-aware AI: full-window agent workspace and toggled project panes
- basic Space leader key surface
- frame close and daemon shutdown commands

The first-pass coding workflow is dashboard-first:

```text
Doom dashboard -> workspace -> Dirvish/Dired -> project coding workspace
```

For now, opening the project coding workspace remains future work. Use the
file, project, Git, terminal, and AI entrypoints directly.

## Commands

Check local setup:

```bash
just doctor
```

Run Doom sync:

```bash
just sync
```

Run checks:

```bash
just check
```

Launch the personal workbench:

```bash
just personal
```

Launch the work workbench:

```bash
just work
```

Restart a profile daemon:

```bash
just restart personal
just restart work
```

Stop a profile daemon:

```bash
just stop personal
just stop work
```

## Keybindings

Custom workbench keybindings use Doom's Space leader.

```text
SPC e     toggle project tree
SPC f f   find file in project
SPC f m   open file manager (Dirvish)
SPC g g   open Git status
SPC p p   switch project
SPC p f   find project file
SPC p s   search project
SPC p o   open project workspace
SPC w p   show active profile
SPC w a   show default AI tool
SPC w s   open startup workspaces
SPC t t   new terminal workspace
SPC t c   toggle Claude project pane
SPC t k   toggle Kiro project pane
SPC t x   toggle Codex project pane
SPC a a   open profile default AI workspace
SPC q f   close frame
SPC q q   stop daemon
```

Doom workspace controls use Doom's defaults:

```text
SPC TAB n     new workspace
SPC TAB TAB   switch workspace
SPC TAB r     rename workspace
SPC TAB d     delete workspace
```
