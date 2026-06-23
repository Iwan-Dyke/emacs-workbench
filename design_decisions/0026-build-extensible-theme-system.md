# 0026. Build Extensible Theme System

Date: 2026-06-22
Status: Accepted

## Context

Personal themes are important to the workbench. The current environment already
uses custom visual themes across Neovim, Ghostty, Starship, Yazi, tmux, and
shell configuration.

The first pass does not need to port every existing theme, but it should make
theme switching and adding new themes straightforward from the beginning.

## Decision

Build theme infrastructure as a first-class part of the workbench.

Theme files should live under:

```text
doom/themes/
```

The system interface module should own theme loading and switching behavior:

```text
doom/modules/system/interface.el
```

Profiles may define a default theme.

The first pass should include the infrastructure and one starter theme:

```text
workbench-wayne-tech
```

Additional themes such as Matrix and Imperial can be added later without
changing the theme architecture.

## Consequences

Theme switching is designed into the workbench rather than added as an
afterthought.

The first implementation can stay focused by shipping one working starter theme.

Theme files remain separate from general interface configuration, keeping visual
style easier to extend and maintain.
