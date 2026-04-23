#!/usr/bin/env bash
# terminility/sessions.sh — Create terminal multiplexer sessions for all git repos in GIT_BASE
set -euo pipefail

GIT_BASE="${TERMINILITY_GIT_BASE:-/mnt/4tb-m2/git}"
ALIAS_FILE="${TERMINILITY_ALIAS_FILE:-$HOME/.terminility_aliases}"
STATE_FILE="${TERMINILITY_STATE_FILE:-$HOME/.terminility_session_paths}"
TERMINILITY_BACKEND="${TERMINILITY_BACKEND:-tmux}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[terminility]${NC} $*"; }
success() { echo -e "${GREEN}[terminility]${NC} $*"; }
warn()    { echo -e "${YELLOW}[terminility]${NC} $*"; }
die()     { echo -e "${RED}[terminility] ERROR:${NC} $*" >&2; exit 1; }

# ─── Backend: tmux ────────────────────────────────────────────────────────────

backend_check_tmux()        { command -v tmux &>/dev/null; }
backend_start_server_tmux() { tmux list-sessions &>/dev/null 2>&1 || { info "Starting tmux server..."; tmux start-server; }; }
session_exists_tmux()       { tmux has-session -t "$1" 2>/dev/null; }
session_create_tmux()       { tmux new-session -d -s "$1" -c "$2"; }
session_kill_tmux()         { tmux kill-session -t "$1"; }
session_env_var_tmux()      { echo "TMUX"; }
build_session_command_tmux() {
    local session_name="$1" repo_path="$2"
    printf 'tmux new-session -A -s %s -c %q' "$session_name" "$repo_path"
}

# ─── Backend: screen (boilerplate) ────────────────────────────────────────────
# screen does not support working-directory at attach time, so we cd inside the
# shell started by the session and rely on screen -r for reattach.

backend_check_screen()        { command -v screen &>/dev/null; }
backend_start_server_screen() { : ; }  # screen has no separate server process
session_exists_screen()       { screen -list 2>/dev/null | grep -qE "\.$1[[:space:]]"; }
session_create_screen()       { screen -dmS "$1" bash -c "$(printf 'cd %q && exec bash' "$2")"; }
session_kill_screen()         { screen -S "$1" -X quit; }
session_env_var_screen()      { echo "STY"; }
build_session_command_screen() {
    local session_name="$1" repo_path="$2"
    local cd_cmd
    cd_cmd="$(printf 'cd %q && exec bash' "$repo_path")"
    printf 'screen -r %q 2>/dev/null || { screen -dmS %q bash -c %q; screen -r %q; }' \
        "$session_name" "$session_name" "$cd_cmd" "$session_name"
}

# ─── Backend dispatcher ────────────────────────────────────────────────────────

backend_check()         { "backend_check_${TERMINILITY_BACKEND}"; }
backend_start_server()  { "backend_start_server_${TERMINILITY_BACKEND}"; }
session_exists()        { "session_exists_${TERMINILITY_BACKEND}" "$1"; }
session_create()        { "session_create_${TERMINILITY_BACKEND}" "$1" "$2"; }
session_kill()          { "session_kill_${TERMINILITY_BACKEND}" "$1"; }
session_env_var()       { "session_env_var_${TERMINILITY_BACKEND}"; }
build_session_command() { "build_session_command_${TERMINILITY_BACKEND}" "$1" "$2"; }

# ─── Session name ─────────────────────────────────────────────────────────────

build_session_name() {
    local repo_path="$1"
    local rel_path="${repo_path#"$GIT_BASE"/}"
    local session_name="${rel_path//\//-}"
    session_name="${session_name// /-}"
    session_name="${session_name//./-}"
    printf '%s\n' "$session_name"
}

# ─── State persistence ────────────────────────────────────────────────────────

load_previous_state() {
    local line repo_path session_name

    if [[ ! -f "$STATE_FILE" ]]; then
        return 1
    fi

    PREVIOUS_SOURCE="$STATE_FILE"

    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            '# GIT_BASE: '*)
                PREVIOUS_GIT_BASE="${line#\# GIT_BASE: }"
                ;;
            ''|'#'*)
                ;;
            *)
                IFS=$'\t' read -r session_name repo_path <<< "$line"
                [[ -n "${session_name:-}" ]] || continue
                PREVIOUS_SESSION_PATHS["$session_name"]="$repo_path"
                ;;
        esac
    done < "$STATE_FILE"

    return 0
}

load_previous_aliases() {
    local alias_command alias_value line repo_path session_name

    if [[ ! -f "$ALIAS_FILE" ]]; then
        return 1
    fi

    PREVIOUS_SOURCE="$ALIAS_FILE"

    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            '# GIT_BASE: '*)
                PREVIOUS_GIT_BASE="${line#\# GIT_BASE: }"
                ;;
            alias\ *)
                # legacy format: alias name='tmux new-session -A -s name -c /path'
                if [[ "$line" =~ ^alias[[:space:]]+([^=]+)=(.+)$ ]]; then
                    session_name="${BASH_REMATCH[1]}"
                    alias_value="${BASH_REMATCH[2]}"

                    if eval "alias_command=$alias_value"; then
                        if [[ "$alias_command" =~ ^tmux[[:space:]]+new-session[[:space:]]+-A[[:space:]]+-s[[:space:]]+[^[:space:]]+[[:space:]]+-c[[:space:]]+(.+)$ ]]; then
                            repo_path="${BASH_REMATCH[1]}"
                            PREVIOUS_SESSION_PATHS["$session_name"]="$repo_path"
                        fi
                    fi
                fi
                ;;
        esac
    done < "$ALIAS_FILE"

    return 0
}

load_previous_session_paths() {
    if load_previous_state; then
        return 0
    fi

    load_previous_aliases || true
}

# ─── RC file injection ────────────────────────────────────────────────────────

ensure_rc_sourced() {
    local source_line="[[ -f $ALIAS_FILE ]] && source $ALIAS_FILE"
    local shell_bin shell_name rc_file injected=0
    declare -A seen_rc

    # Only shells whose RC files support [[ ]] and bash-compatible source syntax
    declare -A SHELL_RC=(
        [bash]="$HOME/.bashrc"
        [zsh]="$HOME/.zshrc"
        [ksh]="$HOME/.kshrc"
        [ksh93]="$HOME/.kshrc"
        [mksh]="$HOME/.mkshrc"
    )

    [[ -f /etc/shells ]] || { warn "/etc/shells not found; skipping RC injection"; return 0; }

    while IFS= read -r shell_bin || [[ -n "$shell_bin" ]]; do
        [[ "$shell_bin" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${shell_bin// }" ]] && continue
        [[ -x "$shell_bin" ]] || continue

        shell_name="$(basename "$shell_bin")"
        rc_file="${SHELL_RC[$shell_name]-}"

        [[ -n "$rc_file" ]] || continue
        [[ -f "$rc_file" ]] || continue
        [[ -n "${seen_rc[$rc_file]+x}" ]] && continue
        seen_rc["$rc_file"]=1

        if grep -qF "$ALIAS_FILE" "$rc_file"; then
            echo -e "  ${YELLOW}skip${NC}   $rc_file  (already sources aliases)"
        else
            { echo ""; echo "# terminility — auto-sourced by sessions.sh"; echo "$source_line"; } >> "$rc_file"
            echo -e "  ${GREEN}inject${NC} $rc_file"
            ((injected++)) || true
        fi
    done < /etc/shells

    if [[ $injected -gt 0 ]]; then
        info "RC files updated. Open a new shell or run: source $ALIAS_FILE"
    fi
}

# ─── Alias and state file writers ─────────────────────────────────────────────

write_alias_file() {
    local alias_dir alias_tmp session_name repo_path env_var session_cmd
    local env_var_name
    env_var_name="$(session_env_var)"

    alias_dir="$(dirname "$ALIAS_FILE")"
    mkdir -p "$alias_dir"
    alias_tmp="$(mktemp "${ALIAS_FILE}.XXXXXX")"

    {
        echo "# terminility — auto-generated ${TERMINILITY_BACKEND} session aliases"
        echo "# Regenerate: bash $SCRIPT_DIR/sessions.sh"
        echo "# GIT_BASE: $GIT_BASE"
        echo ""
        if [[ ${#SESSION_PATHS[@]} -gt 0 ]]; then
            while IFS= read -r session_name; do
                repo_path="${SESSION_PATHS[$session_name]}"
                session_cmd="$(build_session_command "$session_name" "$repo_path")"
                printf '%s() { if [[ -n "$%s" ]]; then cd %q; else %s; fi; }\n' \
                    "$session_name" "$env_var_name" "$repo_path" "$session_cmd"
            done < <(printf '%s\n' "${!SESSION_PATHS[@]}" | sort)
        fi
    } > "$alias_tmp"

    mv "$alias_tmp" "$ALIAS_FILE"
}

write_state_file() {
    local state_dir state_tmp session_name

    state_dir="$(dirname "$STATE_FILE")"
    mkdir -p "$state_dir"
    state_tmp="$(mktemp "${STATE_FILE}.XXXXXX")"

    {
        echo "# terminility — managed ${TERMINILITY_BACKEND} session state"
        echo "# Regenerate: bash $SCRIPT_DIR/sessions.sh"
        echo "# GIT_BASE: $GIT_BASE"
        echo ""
        if [[ ${#SESSION_PATHS[@]} -gt 0 ]]; then
            while IFS= read -r session_name; do
                printf '%s\t%s\n' "$session_name" "${SESSION_PATHS[$session_name]}"
            done < <(printf '%s\n' "${!SESSION_PATHS[@]}" | sort)
        fi
    } > "$state_tmp"

    mv "$state_tmp" "$STATE_FILE"
}

# ─── Session reconciliation ───────────────────────────────────────────────────

reconcile_session() {
    local session_name="$1"
    local repo_path="$2"
    local previous_repo_path="${PREVIOUS_SESSION_PATHS[$session_name]-}"

    if session_exists "$session_name"; then
        if [[ -n "$previous_repo_path" && "$previous_repo_path" != "$repo_path" ]]; then
            session_kill "$session_name"
            session_create "$session_name" "$repo_path"
            echo -e "  ${GREEN}update${NC} $session_name  →  $repo_path"
            ((updated++)) || true
        else
            echo -e "  ${YELLOW}skip${NC}   $session_name  (already valid)"
            ((skipped++)) || true
        fi
    else
        session_create "$session_name" "$repo_path"
        echo -e "  ${GREEN}create${NC} $session_name  →  $repo_path"
        ((created++)) || true
    fi
}

cleanup_stale_sessions() {
    local session_name

    if [[ -z "$PREVIOUS_SOURCE" ]]; then
        return 0
    fi

    if [[ ${#PREVIOUS_SESSION_PATHS[@]} -eq 0 ]]; then
        return 0
    fi

    if [[ -n "$PREVIOUS_GIT_BASE" && "$PREVIOUS_GIT_BASE" != "$GIT_BASE" ]]; then
        warn "Skipping stale session cleanup because the previous managed GIT_BASE was $PREVIOUS_GIT_BASE"
        return 0
    fi

    while IFS= read -r session_name; do
        [[ -n "$session_name" ]] || continue

        if [[ -n "${SESSION_PATHS[$session_name]+x}" ]]; then
            continue
        fi

        if session_exists "$session_name"; then
            session_kill "$session_name"
            echo -e "  ${YELLOW}remove${NC} $session_name  (no longer managed)"
            ((removed++)) || true
        fi
    done < <(printf '%s\n' "${!PREVIOUS_SESSION_PATHS[@]}" | sort)
}

# ─── Main ─────────────────────────────────────────────────────────────────────

[[ -d "$GIT_BASE" ]] || die "GIT_BASE directory not found: $GIT_BASE"
backend_check || die "${TERMINILITY_BACKEND} is not installed. Run install.sh first."
backend_start_server

# ─── Collect git repos ────────────────────────────────────────────────────────
mapfile -t GIT_DIRS < <(find "$GIT_BASE" -mindepth 1 -name ".git" -type d | sort)

if [[ ${#GIT_DIRS[@]} -eq 0 ]]; then
    warn "No git repositories found under $GIT_BASE"
else
    info "Found ${#GIT_DIRS[@]} git repos under $GIT_BASE"
fi
echo ""

created=0
skipped=0
updated=0
removed=0

declare -A SESSION_PATHS  # session_name -> repo_path
declare -A PREVIOUS_SESSION_PATHS  # previous session_name -> repo_path
PREVIOUS_GIT_BASE=""
PREVIOUS_SOURCE=""

load_previous_session_paths

for git_dir in "${GIT_DIRS[@]}"; do
    repo_path="${git_dir%/.git}"
    session_name="$(build_session_name "$repo_path")"

    SESSION_PATHS["$session_name"]="$repo_path"
    reconcile_session "$session_name" "$repo_path"
done

cleanup_stale_sessions

echo ""
success "Sessions: $created created, $updated updated, $removed removed, $skipped already valid."

write_alias_file
write_state_file

echo ""
info "Aliases written to $ALIAS_FILE"
info "Session state written to $STATE_FILE"
echo ""
info "Checking RC files for source line..."
ensure_rc_sourced
echo ""
