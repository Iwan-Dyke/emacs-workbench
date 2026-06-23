# Emacs Workbench

Personal Doom Emacs workbench for editing, projects, Git, files, terminals,
notes, AI tools, and compatibility workflows.

## Structure

- `doom/` contains the Doom Emacs user config.
- `doom/modules/` contains small workbench modules.
- `bin/doctor` checks local setup without changing anything.
- `bin/sync` runs `doom sync`.
- `design_decisions/` contains ADRs explaining project decisions.

## Current Status

This project is in first-pass implementation.

Working so far:

- basic repository structure
- read-only doctor script
- focused sync wrapper
- minimal Doom config skeleton

## Commands

Check local setup:

```bash
./bin/doctor
```

Run Doom sync:

```bash
./bin/sync
```
