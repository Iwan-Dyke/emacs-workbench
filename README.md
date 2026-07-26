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
- `test/` contains unit and behaviour tests.

## Current Status

Working:

- Doom config symlink/install skeleton
- macOS and Debian/Ubuntu/WSL install bootstrap
- root install entrypoint and user launch commands
- read-only doctor script
- focused sync wrapper
- profile-specific personal/work daemons
- Doom workspaces
- startup workspaces (agenda, AI agent, files, repos)
- command centre dashboard (SVG for IC view, rich text for team-lead)
- project coding workspace with full layout (Treemacs | Dashboard | AI)
- project intelligence dashboard (overview, git, languages, deps, CI/CD)
- multi-repo operations dashboard (repos workspace, vtable-based)
- Treemacs project tree on demand
- popup Magit (workspace-scoped, toggle)
- popup terminal (workspace-scoped, toggle)
- Dirvish/Dired file-manager with full-frame layout and cursor memory
- tmux-like terminal workspaces
- tmux-style window navigation (C-h/j/k/l in all states including vterm)
- profile-aware AI: full-window agent workspace and toggled project panes
- org-roam knowledge graph, Jira-to-org sync, ADR discovery
- custom agenda views (today, stale, weeknotes, inbox)
- visual enhancements (lin, org-modern, hl-line)
- frame close and daemon shutdown commands

## Workflow

The default workflow is command-centre-first (work profile):

```text
Command Centre → files workspace (Dirvish) → SPC p o → project workspace
```

`SPC p o` from Dirvish builds the full coding layout at once:

```text
Treemacs | Project Dashboard | AI Pane (kiro/claude/codex)
```

The repos workspace (`SPC w g`) shows all repos under `~/code/` with
branch, status, ahead/behind, and supports fetch/pull/filter/sort.

Startup workspaces (auto-created on first frame):

1. Command Centre (work) or Doom dashboard (personal)
2. Agenda (org-agenda today view)
3. AI (profile default tool running full-window)
4. Files (full-frame Dirvish with cursor memory)
5. Repos (multi-repo status dashboard)

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

Run tests:

```bash
just test           # 307 unit tests (fast, batch Emacs)
just test-behaviour # 97 daemon behaviour tests (starts real workbench)
just test-all       # both
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
SPC g g   toggle popup magit (full-frame, workspace-scoped)
SPC p o   open project workspace (full layout: Treemacs | Dashboard | AI)
SPC p O   open project workspace (lightweight, no layout)
SPC p p   switch project
SPC p f   find project file
SPC p s   search project
SPC w g   repos dashboard
SPC w p   show active profile
SPC w a   show default AI tool
SPC w s   open startup workspaces
SPC w r   enter window resize mode
SPC w t   switch theme
SPC t t   new terminal workspace
SPC t p   toggle popup terminal
SPC t c   toggle Claude project pane
SPC t k   toggle Kiro project pane
SPC t x   toggle Codex project pane
SPC a a   open profile default AI workspace
SPC a p   toggle profile default AI project pane
SPC n a   org agenda
SPC n w   weeknote
SPC n f   org-roam find node
SPC n d   discover ADRs
SPC n j   open jira.org
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

Repos workspace keybindings:

```text
j/k   navigate
RET   open repo as project workspace
g     magit on selected repo
r     refresh statuses
f     cycle filter (all/dirty/clean/behind/ahead)
s     cycle sort (name/status/dirty)
S     sort by clicked column (vtable built-in)
/     search by name
u     fetch all remotes
p     pull selected (clean + behind only)
P     pull all eligible
q     quit
```

Doom workspace controls use Doom's defaults:

```text
SPC TAB n     new workspace
SPC TAB TAB   switch workspace
SPC TAB r     rename workspace
SPC TAB d     delete workspace
```

## Not Yet Done

- Full session restore (ADR 0013 — starts clean each time)
- Config screen for repos roots/theme
- Bitbucket PR status per repo
