# Emacs Workbench

Personal Doom Emacs workbench for editing, projects, Git, files, terminals,
notes, AI tools, and compatibility workflows.

## Structure

- `doom/` contains the Doom Emacs user config.
- `doom/modules/` contains small workbench modules.
- `doom/profiles/` contains tracked profile defaults and local override
  examples.
- `install.sh` is the root install entrypoint.
- `bin/install.d/platform-tools` installs required platform prerequisites.
- `bin/install.d/language-tools` installs optional language servers and formatters.
- `bin/doctor` checks local setup without changing anything.
- `bin/sync` runs `doom sync`.
- `bin/workbench` launches and manages profile-specific Emacs daemons.
- `justfile` contains common project commands.
- `design_decisions/` contains ADRs explaining project decisions.

## Current Status

This project is in first-pass implementation.

Working so far:

- Doom config symlink/install skeleton
- macOS and Debian/Ubuntu/WSL install bootstrap
- root install entrypoint and user launch commands
- read-only doctor script
- focused sync wrapper
- profile-specific personal/work daemons
- Doom workspaces
- startup workspaces (files browser + default AI agent)
- project/file navigation entrypoints
- project coding workspace from a selected directory
- Treemacs project tree on demand
- Magit project status entrypoint
- Dirvish/Dired file-manager entrypoint
- full-frame Dirvish files workspace with directory/cursor memory
- tmux-like terminal workspaces
- tmux-style window navigation
- profile-aware AI: full-window agent workspace and toggled project panes
- basic Space leader key surface
- frame close and daemon shutdown commands

The first-pass coding workflow is dashboard-first:

```text
Doom dashboard -> files workspace (Dirvish) -> project coding workspace
```

Open a project coding workspace with `SPC p o`: from the directory selected in
Dirvish, or by prompt. It creates a workspace named after the directory and
lands on a project placeholder. Pull in the Treemacs tree (`SPC e`) and an AI
pane (`SPC t c/k/x`) on demand. A single command that builds the full
`Treemacs | Code | AI` layout at once is still future work (ADR 0044).

The files workspace opens full-frame Dirvish (listing plus preview) and returns
to the directory and file you last browsed when you switch back to it.

## Commands

Install or repair the local workbench setup:

```bash
./install.sh
```

On macOS, install Homebrew first if it is not already present. The installer
uses Homebrew for Emacs, Doom prerequisites, language servers, and formatters.

On Linux/WSL, the installer supports Debian/Ubuntu-style systems with
`apt-get`. Other Linux package managers are not automated yet.

The installer bootstraps supported host prerequisites, installs Doom when
missing, links this repo as the Doom config, runs Doom sync, creates the
`startup`, `startup-work`, and `workbench` commands, and finishes with the
doctor report.

Platform prerequisites and optional coding tools can also be rerun separately:

```bash
bin/install.d/platform-tools
bin/install.d/language-tools
```

AI CLIs are intentionally user-managed. The installer does not install Codex,
Claude, or Kiro; `doctor` only reports whether they are available.

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
startup
just personal
```

Launch the work workbench:

```bash
startup-work
just work
```

Restart a profile daemon:

```bash
workbench restart personal
workbench restart work
just restart personal
just restart work
```

Stop a profile daemon:

```bash
workbench stop personal
workbench stop work
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
SPC w r   enter window resize mode
SPC t t   new terminal workspace
SPC t p   toggle popup terminal
SPC t c   toggle Claude project pane
SPC t k   toggle Kiro project pane
SPC t x   toggle Codex project pane
SPC a a   open profile default AI workspace
SPC a p   toggle profile default AI project pane
SPC q f   close frame
SPC q q   stop daemon
```

Window navigation mirrors the Neovim motions and works inside vterm too:

```text
C-h   window left (into the Treemacs tree when there is none on the left)
C-j   window down
C-k   window up
C-l   window right (out of the Treemacs tree back to the editor)
C-t   toggle popup terminal
```

Doom workspace controls use Doom's defaults:

```text
SPC TAB n     new workspace
SPC TAB TAB   switch workspace
SPC TAB r     rename workspace
SPC TAB d     delete workspace
```
