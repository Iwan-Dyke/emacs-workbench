# Profiles

The workbench has tracked profile defaults for personal and work use. Each
profile runs in a separate Emacs daemon so their buffers, workspaces, and AI
defaults stay separate.

## Launch Commands

Personal profile:

```bash
startup
```

Work profile:

```bash
startup-work
```

General launcher:

```bash
workbench start personal
workbench start work
workbench restart personal
workbench restart work
workbench stop personal
workbench stop work
```

## Defaults

The personal profile defaults to Codex:

```elisp
(setq workbench/default-ai-tool "codex")
```

The work profile defaults to Kiro:

```elisp
(setq workbench/default-ai-tool "kiro")
```

Use `SPC w p` to show the active profile and `SPC w a` to show the default AI
tool inside Emacs.

## Local Overrides

Tracked examples live in `doom/profiles/`:

- `local.el.example` for machine-specific non-secret overrides
- `secrets.el.example` for values that cannot reasonably live in environment
  variables

Copy an example to the matching untracked file when needed:

```bash
cp doom/profiles/local.el.example doom/profiles/local.el
cp doom/profiles/secrets.el.example doom/profiles/secrets.el
```

Keep machine paths, local preferences, and secrets out of tracked profile files.
