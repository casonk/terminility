#!/usr/bin/env bash
# terminility/install.sh — Install and configure terminal multiplexer with session resume
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIAS_FILE="${TERMINILITY_ALIAS_FILE:-$HOME/.terminility_aliases}"
TERMINILITY_BACKEND="${TERMINILITY_BACKEND:-tmux}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[terminility]${NC} $*"; }
success() { echo -e "${GREEN}[terminility]${NC} $*"; }
warn()    { echo -e "${YELLOW}[terminility]${NC} $*"; }
die()     { echo -e "${RED}[terminility] ERROR:${NC} $*" >&2; exit 1; }

# ─── Detect package manager ───────────────────────────────────────────────────
detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then   echo "apt"
    elif command -v dnf &>/dev/null;          then echo "dnf"
    elif command -v pacman &>/dev/null;       then echo "pacman"
    elif command -v brew &>/dev/null;         then echo "brew"
    elif command -v zypper &>/dev/null;       then echo "zypper"
    else die "No supported package manager found (apt/dnf/pacman/brew/zypper)."
    fi
}

# ─── Backend: tmux ────────────────────────────────────────────────────────────

install_tmux() {
    if command -v tmux &>/dev/null; then
        success "tmux $(tmux -V | cut -d' ' -f2) is already installed."
        return
    fi

    local pm; pm=$(detect_pkg_manager)
    info "Installing tmux via $pm..."
    case "$pm" in
        apt)    sudo apt-get update -qq && sudo apt-get install -y tmux ;;
        dnf)    sudo dnf install -y tmux ;;
        pacman) sudo pacman -Sy --noconfirm tmux ;;
        brew)   brew install tmux ;;
        zypper) sudo zypper install -y tmux ;;
    esac
    success "tmux installed: $(tmux -V)"
}

install_tpm() {
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    if [[ -d "$tpm_dir/.git" ]]; then
        info "TPM already installed, pulling latest..."
        git -C "$tpm_dir" pull --quiet
    else
        info "Cloning TPM into $tpm_dir..."
        git clone --quiet https://github.com/tmux-plugins/tpm "$tpm_dir"
    fi
    success "TPM ready at $tpm_dir"
}

install_tmux_config() {
    local src="$REPO_DIR/tmux.conf" dest="$HOME/.tmux.conf"
    [[ -f "$src" ]] || die "tmux.conf not found at $src"

    if [[ -f "$dest" ]]; then
        local backup="${dest}.bak.$(date +%Y%m%d_%H%M%S)"
        warn "Existing ~/.tmux.conf backed up to $backup"
        cp "$dest" "$backup"
    fi

    cp "$src" "$dest"
    success "Config written to $dest"
}

install_tmux_plugins() {
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    info "Installing tmux plugins (tmux-resurrect, tmux-continuum)..."
    env TMUX_TMPDIR=/tmp tmux new-session -d -s _terminility_install 2>/dev/null || true
    "$tpm_dir/bin/install_plugins" 2>&1 | grep -v "^$" || true
    tmux kill-session -t _terminility_install 2>/dev/null || true
    success "Plugins installed."
}

reload_tmux() {
    if tmux list-sessions &>/dev/null 2>&1; then
        info "Reloading running tmux server..."
        tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true
        success "Config reloaded in running tmux server."
    fi
}

install_tmux_backend() {
    install_tmux
    install_tpm
    install_tmux_config
    install_tmux_plugins
    reload_tmux
}

print_quickref_tmux() {
    echo -e "  ${CYAN}Quick reference:${NC}"
    echo "    tmux                    — start or attach to a session"
    echo "    <session-alias>         — attach to a git repo session (e.g. util-repos-terminility)"
    echo "    bash sessions.sh        — rescan repos and refresh sessions/aliases"
    echo "    prefix + Ctrl+s         — manually save session"
    echo "    prefix + Ctrl+r         — manually restore session"
    echo "    prefix + r              — reload config"
    echo "    prefix + |              — split horizontally"
    echo "    prefix + -              — split vertically"
}

# ─── Backend: screen (boilerplate) ────────────────────────────────────────────
# screen does not have a plugin manager or a repo-managed config equivalent.
# Add install_screenrc here when a .screenrc is added to the repo.

install_screen() {
    if command -v screen &>/dev/null; then
        success "screen $(screen --version 2>&1 | head -1) is already installed."
        return
    fi

    local pm; pm=$(detect_pkg_manager)
    info "Installing screen via $pm..."
    case "$pm" in
        apt)    sudo apt-get update -qq && sudo apt-get install -y screen ;;
        dnf)    sudo dnf install -y screen ;;
        pacman) sudo pacman -Sy --noconfirm screen ;;
        brew)   brew install screen ;;
        zypper) sudo zypper install -y screen ;;
    esac
    success "screen installed: $(screen --version 2>&1 | head -1)"
}

install_screen_backend() {
    install_screen
}

print_quickref_screen() {
    echo -e "  ${CYAN}Quick reference:${NC}"
    echo "    screen                  — start a new screen session"
    echo "    <session-alias>         — attach to a git repo session (e.g. util-repos-terminility)"
    echo "    bash sessions.sh        — rescan repos and refresh sessions/aliases"
    echo "    Ctrl+a d                — detach from current session"
    echo "    Ctrl+a ?                — show key bindings"
    echo "    Ctrl+a |                — split vertically"
    echo "    Ctrl+a S                — split horizontally"
}

# ─── Backend dispatcher ────────────────────────────────────────────────────────

install_backend()     { "install_${TERMINILITY_BACKEND}_backend"; }
print_quickref()      { "print_quickref_${TERMINILITY_BACKEND}"; }

# ─── Session scan (backend-agnostic) ─────────────────────────────────────────
# sessions.sh handles alias generation and RC file injection via ensure_rc_sourced.

setup_sessions() {
    info "Scanning git repos and creating ${TERMINILITY_BACKEND} sessions..."
    TERMINILITY_BACKEND="$TERMINILITY_BACKEND" bash "$REPO_DIR/sessions.sh"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════╗"
    echo -e "║         terminility installer        ║"
    echo -e "╚══════════════════════════════════════╝${NC}"
    echo ""
    info "Backend: ${TERMINILITY_BACKEND}"
    echo ""

    install_backend
    setup_sessions

    echo ""
    success "All done! ${TERMINILITY_BACKEND} is configured with terminility session management."
    echo ""
    print_quickref
    echo ""
    echo -e "  ${YELLOW}Note:${NC} Open a new shell (or run: source $ALIAS_FILE) to activate aliases."
    echo ""
}

main "$@"
