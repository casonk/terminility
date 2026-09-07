#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf '[test] shell syntax\n'
bash -n "$ROOT_DIR/install.sh" "$ROOT_DIR/setup.sh" "$ROOT_DIR/sessions.sh" "$ROOT_DIR/scripts/run_tachometer_profile.sh"

if command -v tmux >/dev/null 2>&1; then
  printf '[test] tmux config parse\n'
  config_copy="$(mktemp)"
  trap 'rm -f "$config_copy"' EXIT
  grep -vF "run '~/.tmux/plugins/tpm/tpm'" "$ROOT_DIR/tmux.conf" > "$config_copy"
  tmux -f "$config_copy" start-server
  tmux -f "$config_copy" source-file "$config_copy"
else
  printf '[skip] tmux config parse (tmux not installed)\n'
fi

printf 'Validation passed.\n'
