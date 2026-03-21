#!/usr/bin/env bash
# terminility/install.sh — Install and configure tmux with session resume
set -euo pipefail

TMUX_CONF_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tmux.conf"
TMUX_CONF_DEST="$HOME/.tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm"

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

# ─── Install tmux ─────────────────────────────────────────────────────────────
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

# ─── Install TPM (tmux plugin manager) ────────────────────────────────────────
install_tpm() {
    if [[ -d "$TPM_DIR/.git" ]]; then
        info "TPM already installed, pulling latest..."
        git -C "$TPM_DIR" pull --quiet
    else
        info "Cloning TPM into $TPM_DIR..."
        git clone --quiet https://github.com/tmux-plugins/tpm "$TPM_DIR"
    fi
    success "TPM ready at $TPM_DIR"
}

# ─── Install tmux config ──────────────────────────────────────────────────────
install_config() {
    if [[ ! -f "$TMUX_CONF_SRC" ]]; then
        die "tmux.conf not found at $TMUX_CONF_SRC"
    fi

    if [[ -f "$TMUX_CONF_DEST" ]]; then
        local backup="${TMUX_CONF_DEST}.bak.$(date +%Y%m%d_%H%M%S)"
        warn "Existing ~/.tmux.conf backed up to $backup"
        cp "$TMUX_CONF_DEST" "$backup"
    fi

    cp "$TMUX_CONF_SRC" "$TMUX_CONF_DEST"
    success "Config written to $TMUX_CONF_DEST"
}

# ─── Install plugins headlessly ───────────────────────────────────────────────
install_plugins() {
    info "Installing tmux plugins (tmux-resurrect, tmux-continuum)..."
    # Start a temporary detached tmux server and run TPM install
    env TMUX_TMPDIR=/tmp tmux new-session -d -s _terminility_install 2>/dev/null || true
    "$TPM_DIR/bin/install_plugins" 2>&1 | grep -v "^$" || true
    tmux kill-session -t _terminility_install 2>/dev/null || true
    success "Plugins installed."
}

# ─── Reload running tmux server (if any) ──────────────────────────────────────
reload_tmux() {
    if tmux list-sessions &>/dev/null 2>&1; then
        info "Reloading running tmux server..."
        tmux source-file "$TMUX_CONF_DEST" 2>/dev/null || true
        success "Config reloaded in running tmux server."
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════╗"
    echo -e "║         terminility installer        ║"
    echo -e "╚══════════════════════════════════════╝${NC}"
    echo ""

    install_tmux
    install_tpm
    install_config
    install_plugins
    reload_tmux

    echo ""
    success "All done! tmux is configured with auto-save (every 15 min) and auto-restore."
    echo ""
    echo -e "  ${CYAN}Quick reference:${NC}"
    echo "    tmux                    — start or attach to a session"
    echo "    prefix + Ctrl+s         — manually save session"
    echo "    prefix + Ctrl+r         — manually restore session"
    echo "    prefix + r              — reload config"
    echo "    prefix + |              — split horizontally"
    echo "    prefix + -              — split vertically"
    echo ""
}

main "$@"
