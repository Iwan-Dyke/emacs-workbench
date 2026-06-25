# 0055. Bootstrap Supported Platforms in the Installer

Date: 2026-06-25
Status: Accepted

## Context

The intended first-run experience is:

```bash
git clone <repo-url> ~/homelab/projects/emacs-workbench
cd ~/homelab/projects/emacs-workbench
./install.sh
```

ADR 0053 made `install.sh` the top-level entrypoint, but the implementation
still expected Emacs and Doom to already exist. That is not enough for a new
laptop or a fresh WSL environment.

The workbench has two primary bootstrap targets:

- macOS
- Linux/WSL, initially Debian/Ubuntu via `apt-get`

Other Linux package managers can be added later, but guessing package names
across distributions would make the installer harder to trust.

## Decision

Make `bin/install` bootstrap supported host prerequisites before linking and
syncing the Doom config.

Supported package-manager paths:

```text
macOS        -> Homebrew
Linux / WSL  -> apt-get
```

The installer may install known prerequisite packages through the supported
package manager when they are missing. It should not install Homebrew itself in
the first implementation; if `brew` is missing, print the Homebrew install
command and stop. Running a remote shell installer is a larger trust boundary
than installing packages through an already configured package manager.

For Linux, support `apt-get` first. Use `sudo` when not running as root. If
`apt-get` is missing, stop with a clear unsupported-platform message.

Install Doom when `doom` is missing and `~/.emacs.d` is absent:

```bash
git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.emacs.d
~/.emacs.d/bin/doom install
```

If `~/.emacs.d` exists but does not provide Doom, stop instead of overwriting it.

After prerequisites and Doom are available, continue with the existing install
flow:

1. link `~/.config/doom` to this repo's `doom/`
2. install user launch wrappers
3. run Doom sync
4. run the read-only doctor report

## Consequences

A new macOS or Ubuntu/WSL machine can move much closer to one-command setup.

The installer now performs network and package-manager operations, so output and
failure modes must stay explicit.

Homebrew installation remains manual for now. This preserves a trust boundary
while still making the missing step obvious.

Unsupported Linux distributions get a clear failure instead of a best-effort
package install that may leave the machine in a partial state.
