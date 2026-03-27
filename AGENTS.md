# AGENTS.md

## Project Purpose

A Bash toolkit to install, configure, and manage tmux with automatic session save/restore. Scans git repositories to create dedicated tmux sessions with shell aliases for quick access.

## Repository Layout

- `install.sh` — Installs tmux and TPM (tmux plugin manager) via system package manager
- `setup.sh` — Deploys tmux.conf, installs plugins, generates sessions and aliases
- `sessions.sh` — Scans git directories and creates/manages tmux sessions
- `tmux.conf` — Sensible tmux configuration (mouse, vim keys, splits, colors, plugins)
- `docs/` — Documentation and architecture diagrams
  - `contributor-architecture-blueprint.md` — Architecture overview
  - `diagrams/` — PlantUML and draw.io source files
- `README.md` — Features, setup, and quick reference

## Setup

```bash
# Install tmux and plugin manager
./install.sh

# Deploy config, plugins, sessions, and aliases
./setup.sh
```

## Operating Rules

- All scripts must be POSIX-compatible Bash (no bashisms that break on older shells).
- Favor plain Bash and standard system tooling — no external dependencies beyond tmux and git.
- Scripts must handle missing commands and permission errors gracefully.
- Test on both Linux (apt, dnf) and macOS (brew) when possible.
- Keep `tmux.conf` well-commented for user customization.
- Update `docs/contributor-architecture-blueprint.md` when changing script flow or adding new scripts.
- Prefer additive changes — do not remove existing tmux keybindings without discussion.

## Script Conventions

- Use `set -euo pipefail` at the top of all scripts.
- Use functions for logical grouping.
- Print status messages with consistent formatting (e.g., `echo "==> Installing tmux"`).
- Detect OS/package manager automatically — do not hardcode paths.

## Portfolio Standards Reference

For portfolio-wide repository standards and baseline conventions, consult the control-plane repo at `./util-repos/traction-control` from the portfolio root.

Start with:
- `./util-repos/traction-control/AGENTS.md`
- `./util-repos/traction-control/README.md`
- `./util-repos/traction-control/LESSONSLEARNED.md`

Shared implementation repos available portfolio-wide:
- `./util-repos/auto-pass` for KeePassXC-backed password management and secret retrieval/update flows
- `./util-repos/nordility` for NordVPN-based VPN switching and connection orchestration
- `./util-repos/shock-relay` for external messaging across supported providers such as Signal, Telegram, Twilio SMS, WhatsApp, and Gmail IMAP

When another repo needs password management, VPN switching, or external messaging, prefer integrating with these repos instead of re-implementing the capability locally.

## Agent Memory

Use `./LESSONSLEARNED.md` as the tracked durable lessons file for this repo.
Use `./CHATHISTORY.md` as the standard local handoff file for this repo.

- `LESSONSLEARNED.md` is tracked and should capture only reusable lessons.
- `CHATHISTORY.md` is local-only, gitignored, and should capture transient handoff context.
- Read `LESSONSLEARNED.md` and `CHATHISTORY.md` after `AGENTS.md` when resuming work.
- Add durable lessons to `LESSONSLEARNED.md` when they should influence future sessions.
- Keep transient entries brief and focused on script changes, platform checks, blockers, and next steps.
