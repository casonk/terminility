# Contributor Architecture Blueprint

This document is a concise map of how terminility installs, configures, and manages tmux sessions across a git repository workspace.

## Visual Diagrams

- PlantUML source: `docs/diagrams/repo-architecture.puml`
- PlantUML renders:
  - `docs/diagrams/repo-architecture.puml.svg`
  - `docs/diagrams/repo-architecture.puml.png`

## High-Level Layers

1. **Installation Layer** (`install.sh`)
   - Detects the system package manager (apt / dnf / pacman / brew / zypper) and installs tmux.
   - Clones or updates TPM (tmux Plugin Manager) into `~/.tmux/plugins/tpm`.
   - Backs up any existing `~/.tmux.conf` before deploying the repo's config.
   - Runs TPM headlessly to install plugins (`tmux-resurrect`, `tmux-continuum`).
   - Invokes `sessions.sh` to scan git repos and create sessions.
   - Wires the alias loader line into `~/.bashrc` and/or `~/.zshrc`.

2. **Configuration Layer** (`tmux.conf` → `~/.tmux.conf`)
   - Declares sensible defaults: 256-color + true-color, mouse, 50k history, base-index 1.
   - Binds intuitive split/navigation shortcuts and a config-reload key.
   - Registers plugins via TPM: `tmux-sensible`, `tmux-resurrect`, `tmux-continuum`.
   - Sets session-resume policy: auto-save every 15 minutes, auto-restore on server start.
   - TPM `run` directive is always the last line.

3. **Session Management Layer** (`sessions.sh`)
   - Scans `GIT_BASE` (default: `/mnt/4tb-m2/git`) with `find … -name ".git" -type d`.
   - Derives a tmux-safe session name from the relative path (`/` → `-`, spaces/dots → `-`).
   - Loads the previous managed session map from `~/.terminility_session_paths` (falling back to the legacy alias file when upgrading from older runs).
   - Recreates a managed session when the tracked repo path changed.
   - Removes a previously managed session when it no longer appears under the same managed `GIT_BASE`.
   - Ensures the tmux server is running before session creation (`tmux start-server`).
   - Writes `~/.terminility_aliases` and `~/.terminility_session_paths` atomically on every run.

4. **Alias Layer** (`~/.terminility_aliases` → `~/.bash_aliases` / `~/.zshrc`)
   - Each alias resolves to `tmux new-session -A -s <name> -c <repo-path>`.
     - `-A`: attach if the session already exists, create it fresh otherwise.
     - `-c`: always start in the repo's root directory.
   - The alias file is regenerated atomically on every `sessions.sh` run; no stale entries accumulate.
   - `install.sh` appends a one-line source guard to shell RC files (idempotent).

## Component Map

```
terminility/
├── install.sh          # Entry point — orchestrates all layers
├── sessions.sh         # Session scanning, creation, alias generation
├── tmux.conf           # Tmux configuration source (deployed to ~/.tmux.conf)
├── docs/
│   ├── contributor-architecture-blueprint.md   # This file
│   └── diagrams/
│       ├── repo-architecture.puml              # PlantUML source
│       ├── repo-architecture.puml.svg          # Rendered SVG
│       └── repo-architecture.puml.png          # Rendered PNG
└── README.md
```

**Runtime artifacts (not tracked):**

```
~/.tmux.conf                    # Deployed config (copied from tmux.conf)
~/.tmux/plugins/tpm/            # TPM clone
~/.tmux/plugins/tmux-resurrect/ # Session save/restore plugin
~/.tmux/plugins/tmux-continuum/ # Auto-save/restore plugin
~/.tmux/resurrect/              # tmux-resurrect save files
~/.terminility_aliases          # Generated alias file
~/.terminility_session_paths    # Generated managed-session path state
```

## Data Flow

```
/mnt/4tb-m2/git/**/.git    ← scanned by sessions.sh
         │
         ▼
tmux sessions (created, updated, or pruned to match managed repos)
         │
         ├──────────────► ~/.terminility_session_paths  ← rewritten each run
         │
         ▼
~/.terminility_aliases      ← rewritten each run
         │
         ▼
~/.bash_aliases / ~/.zshrc  ← source guard added once by install.sh
         │
         ▼
shell aliases active in every new terminal session
```

## Session Naming Convention

| Repo path (relative to GIT_BASE) | Session name |
|-----------------------------------|--------------|
| `fedora-debugg` | `fedora-debugg` |
| `util-repos/terminility` | `util-repos-terminility` |
| `research-repos/citegres` | `research-repos-citegres` |
| `casonk.github.io` | `casonk-github-io` |

Rules applied in order:
1. Strip `GIT_BASE/` prefix.
2. Replace `/` with `-`.
3. Replace spaces and `.` with `-`.

## Key Entry Points

| Script | Purpose |
|--------|---------|
| `bash install.sh` | Full install: tmux + TPM + plugins + config + sessions + alias wiring |
| `bash sessions.sh` | Rescan repos, reconcile managed sessions, regenerate aliases/state (safe to re-run anytime) |
| `source ~/.terminility_aliases` | Activate aliases in the current shell without opening a new one |
| `tmux new-session -A -s <name>` | What each alias expands to |

## Shared Patterns

- **Idempotency everywhere**: `install.sh` and `sessions.sh` are safe to re-run at any time with no side effects.
- **Environment overrides**: `TERMINILITY_GIT_BASE`, `TERMINILITY_ALIAS_FILE`, and `TERMINILITY_STATE_FILE` let users redirect scanning and generated output without modifying scripts.
- **Tracked reconciliation**: stale session cleanup is limited to sessions previously managed for the same `GIT_BASE`, so unrelated tmux sessions are left alone.
- **Backup before overwrite**: `~/.tmux.conf` is timestamped-backed-up before any deployment.
- **No credentials or secrets**: nothing sensitive is read, stored, or committed.
- **Generated file atomicity**: `~/.terminility_aliases` and `~/.terminility_session_paths` are written via temp files plus `mv`, so reruns replace the managed view cleanly.
