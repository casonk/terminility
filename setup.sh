#!/usr/bin/env bash
# terminility/setup.sh — Bootstrap diagram rendering tools (PlantUML + draw.io)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$REPO_ROOT/tools"
BIN_DIR="$TOOLS_DIR/bin"
PLANTUML_DIR="$TOOLS_DIR/plantuml"
DRAWIO_DIR="$TOOLS_DIR/drawio"

PLANTUML_VERSION="${PLANTUML_VERSION:-1.2026.2}"
DRAWIO_VERSION="${DRAWIO_VERSION:-24.7.17}"
SKIP_DRAWIO="${SKIP_DRAWIO:-0}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[setup]${NC} $*"; }
success() { echo -e "${GREEN}[setup]${NC} $*"; }
warn()    { echo -e "${YELLOW}[setup]${NC} $*"; }
die()     { echo -e "${RED}[setup] ERROR:${NC} $*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: bash setup.sh [options]

Options:
  --skip-drawio    Skip draw.io AppImage download
  -h, --help       Show this help text

Environment overrides:
  PLANTUML_VERSION  PlantUML jar version  (default: $PLANTUML_VERSION)
  DRAWIO_VERSION    draw.io version        (default: $DRAWIO_VERSION)
  SKIP_DRAWIO       Set to 1 to skip drawio (default: 0)
EOF
}

for arg in "$@"; do
    case "$arg" in
        --skip-drawio) SKIP_DRAWIO=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $arg" ;;
    esac
done

# ─── PlantUML ─────────────────────────────────────────────────────────────────
install_plantuml() {
    command -v java &>/dev/null || die "java is required for PlantUML. Install JRE 11+ first."
    mkdir -p "$PLANTUML_DIR" "$BIN_DIR"
    local jar="$PLANTUML_DIR/plantuml.jar"
    local url="https://github.com/plantuml/plantuml/releases/download/v${PLANTUML_VERSION}/plantuml-${PLANTUML_VERSION}.jar"
    if [[ -f "$jar" ]]; then
        info "PlantUML jar already present: $jar"
    else
        info "Downloading PlantUML $PLANTUML_VERSION..."
        curl -fL --retry 3 --retry-delay 2 -o "$jar" "$url"
    fi
    cat > "$BIN_DIR/plantuml" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec java -jar "$DIR/../plantuml/plantuml.jar" "$@"
WRAPPER
    chmod +x "$BIN_DIR/plantuml"
    success "PlantUML wrapper: $BIN_DIR/plantuml"
}

# ─── draw.io ──────────────────────────────────────────────────────────────────
install_drawio() {
    if [[ "$SKIP_DRAWIO" -eq 1 ]]; then
        warn "Skipping draw.io (--skip-drawio)."
        return
    fi
    local arch; arch="$(uname -m)"
    if [[ "$arch" != "x86_64" ]]; then
        warn "draw.io AppImage auto-install supports x86_64 only. Skipping for: $arch"
        return
    fi
    mkdir -p "$DRAWIO_DIR" "$BIN_DIR"
    local appimage="$DRAWIO_DIR/drawio.AppImage"
    local url="https://github.com/jgraph/drawio-desktop/releases/download/v${DRAWIO_VERSION}/drawio-x86_64-${DRAWIO_VERSION}.AppImage"
    if [[ -f "$appimage" ]]; then
        info "draw.io AppImage already present: $appimage"
    else
        info "Downloading draw.io desktop $DRAWIO_VERSION..."
        curl -fL --retry 3 --retry-delay 2 -o "$appimage" "$url"
        chmod +x "$appimage"
    fi

    # Extract AppImage so it works without FUSE
    local extracted="$DRAWIO_DIR/squashfs-root"
    if [[ ! -d "$extracted" ]]; then
        info "Extracting draw.io AppImage (avoids FUSE requirement)..."
        cd "$DRAWIO_DIR" && "$appimage" --appimage-extract >/dev/null && cd "$REPO_ROOT"
    else
        info "draw.io already extracted: $extracted"
    fi

    cat > "$BIN_DIR/drawio" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPLAY="${DISPLAY:-:0}"
exec "$DIR/../drawio/squashfs-root/drawio" --no-sandbox --disable-gpu "$@"
WRAPPER
    chmod +x "$BIN_DIR/drawio"
    success "draw.io wrapper: $BIN_DIR/drawio"
}

# ─── Render diagrams ──────────────────────────────────────────────────────────
render_diagrams() {
    local diagrams="$REPO_ROOT/docs/diagrams"
    info "Rendering diagrams in $diagrams..."

    # PlantUML
    if command -v java &>/dev/null && [[ -f "$PLANTUML_DIR/plantuml.jar" ]]; then
        java -jar "$PLANTUML_DIR/plantuml.jar" -tsvg -o "$diagrams" "$diagrams/repo-architecture.puml"
        java -jar "$PLANTUML_DIR/plantuml.jar" -tpng -o "$diagrams" "$diagrams/repo-architecture.puml"
        success "PlantUML: repo-architecture.puml.svg + .png"
    else
        warn "Skipping PlantUML render (java or jar not available)."
    fi

    # draw.io
    local drawio_bin="$DRAWIO_DIR/squashfs-root/drawio"
    if [[ -f "$drawio_bin" ]]; then
        local disp="${DISPLAY:-:0}"
        DISPLAY="$disp" "$drawio_bin" --no-sandbox --disable-gpu -x -f svg \
            -o "$diagrams/repo-architecture.drawio.svg" \
            "$diagrams/repo-architecture.drawio" 2>&1
        DISPLAY="$disp" "$drawio_bin" --no-sandbox --disable-gpu -x -f png \
            -o "$diagrams/repo-architecture.drawio.png" \
            "$diagrams/repo-architecture.drawio" 2>&1
        success "draw.io: repo-architecture.drawio.svg + .png"
    else
        warn "Skipping draw.io render (AppImage not extracted yet — run setup.sh first)."
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════╗"
    echo -e "║         terminility setup            ║"
    echo -e "╚══════════════════════════════════════╝${NC}"
    echo ""

    install_plantuml
    install_drawio
    render_diagrams

    echo ""
    success "Setup complete."
    echo ""
    echo -e "  ${CYAN}Add local tools to PATH for this shell:${NC}"
    echo "    export PATH=\"$BIN_DIR:\$PATH\""
    echo ""
    echo -e "  ${CYAN}Re-render diagrams any time:${NC}"
    echo "    bash setup.sh"
    echo ""
}

main "$@"
