#!/usr/bin/env bash
# terminility/sessions.sh — Create tmux sessions for all git repos in GIT_BASE
set -euo pipefail

GIT_BASE="${TERMINILITY_GIT_BASE:-/mnt/4tb-m2/git}"
ALIAS_FILE="${TERMINILITY_ALIAS_FILE:-$HOME/.terminility_aliases}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[terminility]${NC} $*"; }
success() { echo -e "${GREEN}[terminility]${NC} $*"; }
warn()    { echo -e "${YELLOW}[terminility]${NC} $*"; }
die()     { echo -e "${RED}[terminility] ERROR:${NC} $*" >&2; exit 1; }

[[ -d "$GIT_BASE" ]] || die "GIT_BASE directory not found: $GIT_BASE"
command -v tmux &>/dev/null || die "tmux is not installed. Run install.sh first."

# ─── Ensure tmux server is running ────────────────────────────────────────────
if ! tmux list-sessions &>/dev/null 2>&1; then
    info "Starting tmux server..."
    tmux start-server
fi

# ─── Collect git repos ────────────────────────────────────────────────────────
mapfile -t GIT_DIRS < <(find "$GIT_BASE" -mindepth 1 -name ".git" -type d | sort)

if [[ ${#GIT_DIRS[@]} -eq 0 ]]; then
    warn "No git repositories found under $GIT_BASE"
    exit 0
fi

info "Found ${#GIT_DIRS[@]} git repos under $GIT_BASE"
echo ""

created=0
skipped=0

declare -A SESSION_PATHS  # session_name -> repo_path

for git_dir in "${GIT_DIRS[@]}"; do
    repo_path="${git_dir%/.git}"
    rel_path="${repo_path#"$GIT_BASE"/}"

    # Build session name: replace / spaces and dots with -
    session_name="${rel_path//\//-}"
    session_name="${session_name// /-}"
    session_name="${session_name//./-}"

    SESSION_PATHS["$session_name"]="$repo_path"

    if tmux has-session -t "$session_name" 2>/dev/null; then
        echo -e "  ${YELLOW}skip${NC}   $session_name  (already exists)"
        ((skipped++)) || true
    else
        tmux new-session -d -s "$session_name" -c "$repo_path"
        echo -e "  ${GREEN}create${NC} $session_name  →  $repo_path"
        ((created++)) || true
    fi
done

echo ""
success "Sessions: $created created, $skipped already existed."

# ─── Write aliases file ───────────────────────────────────────────────────────
{
    echo "# terminility — auto-generated tmux session aliases"
    echo "# Regenerate: bash $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sessions.sh"
    echo "# GIT_BASE: $GIT_BASE"
    echo ""
    for session_name in $(echo "${!SESSION_PATHS[@]}" | tr ' ' '\n' | sort); do
        repo_path="${SESSION_PATHS[$session_name]}"
        # -A: attach if exists, create if not; -c: start in repo directory
        echo "alias ${session_name}='tmux new-session -A -s ${session_name} -c ${repo_path}'"
    done
} > "$ALIAS_FILE"

echo ""
info "Aliases written to $ALIAS_FILE"
info "Source it in your shell: source $ALIAS_FILE"
echo ""
echo -e "  ${CYAN}Tip:${NC} Add the following to ~/.bashrc or ~/.zshrc so aliases load automatically:"
echo "    [[ -f $ALIAS_FILE ]] && source $ALIAS_FILE"
echo ""
