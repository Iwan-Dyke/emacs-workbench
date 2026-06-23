# 0027. Use Manual Project Discovery First

Date: 2026-06-22
Status: Accepted

## Context

Emacs and Doom support project-aware workflows such as switching projects,
finding files in a project, searching a project, opening project terminals, and
using project-local Git state.

The workbench could scan configured directories to discover projects, but
automatic project discovery adds more behavior and assumptions before the core
workbench is stable.

## Decision

Use Doom's normal manual project discovery and project memory for the first
pass.

Projects become known by opening or switching to them through normal Doom/Emacs
project commands.

Do not scan configured project roots automatically in the first version.

## Consequences

The first implementation stays simpler and avoids surprising project lists.

Project auto-detection can be added later if manually opening projects becomes
annoying.

Profiles may still define project-related settings later, but they are not
required for first-pass project discovery.
