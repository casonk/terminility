# terminility

> Install, configure, and supercharge **tmux** with automatic session save/restore on any Linux or macOS machine.

## What it does

- Installs **tmux** via your system's package manager (auto-detected)
- Installs **[TPM](https://github.com/tmux-plugins/tpm)** (tmux plugin manager)
- Deploys a sensible `~/.tmux.conf` with:
  - Mouse support
  - Vim-style pane navigation
  - Intuitive split shortcuts (`|` / `-`)
  - 256-color + true-color support
- Installs and configures:
  - **[tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)** — save and restore tmux sessions
  - **[tmux-continuum](https://github.com/tmux-plugins/tmux-continuum)** — automatic save every 15 minutes & auto-restore on startup
- **Scans all git repos** under your configured base directory and creates a dedicated tmux session for each one
- **Generates shell aliases** — type the session name to instantly jump into it

## Architecture

- Contributor architecture blueprint: [`docs/contributor-architecture-blueprint.md`](docs/contributor-architecture-blueprint.md)
- PlantUML diagram source: [`docs/diagrams/repo-architecture.puml`](docs/diagrams/repo-architecture.puml)

## Requirements

| Tool | Notes |
|------|-------|
| `git` | Required to clone TPM and plugins |
| `bash` | Version 4+ |
| One of: `apt`, `dnf`, `pacman`, `brew`, `zypper` | For installing tmux |

## Install

```bash
git clone https://github.com/<your-username>/terminility.git
cd terminility
bash install.sh
```

> An existing `~/.tmux.conf` will be automatically backed up before being replaced.

## Quick Reference

| Shortcut / Command | Action |
|----------|--------|
| `<session-name>` | Attach to a git repo session (e.g. `util-repos-terminility`) |
| `bash sessions.sh` | Rescan repos, create new sessions, refresh aliases |
| `prefix + Ctrl+s` | Manually save session |
| `prefix + Ctrl+r` | Manually restore session |
| `prefix + r` | Reload config |
| `prefix + \|` | Split pane horizontally |
| `prefix + -` | Split pane vertically |
| `prefix + h/j/k/l` | Navigate panes (vim-style) |
| `prefix + H/J/K/L` | Resize panes |

> Default prefix is `Ctrl+b` (tmux default). Swap to `Ctrl+a` by editing the comments at the top of `tmux.conf`.

## Git Repo Sessions

`sessions.sh` scans a base directory for git repositories and creates a dedicated tmux session for each one. Sessions are **idempotent** — already-existing sessions are never recreated or interrupted.

**Session naming:** path segments are joined with `-` (e.g. `research-repos-citegres`).

**Shell aliases** are written to `~/.terminility_aliases` and sourced automatically from `~/.bashrc`/`~/.zshrc`. Each alias resolves to:
```bash
tmux new-session -A -s <session-name> -c <repo-path>
```
This attaches to an existing session or creates a fresh one, always starting in the repo directory.

**To rescan after adding new repos:**
```bash
bash sessions.sh
source ~/.terminility_aliases
```

**Override the base directory:**
```bash
TERMINILITY_GIT_BASE=~/projects bash sessions.sh
```

## Session Resume

Sessions are **automatically saved every 15 minutes** and **automatically restored** the next time you start tmux.

Saves are stored in `~/.tmux/resurrect/`.

## Customization

Edit `~/.tmux.conf` directly, or fork this repo and modify `tmux.conf` before running `install.sh`. After any change, reload with:

```bash
tmux source-file ~/.tmux.conf
# or inside tmux: prefix + r
```

To add more plugins, append `set -g @plugin '...'` lines before the `run '~/.tmux/plugins/tpm/tpm'` line, then install with `prefix + I`.

## Supported Platforms

| OS | Package Manager |
|----|----------------|
| Debian / Ubuntu | `apt` |
| Fedora / RHEL / CentOS | `dnf` |
| Arch Linux | `pacman` |
| openSUSE | `zypper` |
| macOS | `brew` |
