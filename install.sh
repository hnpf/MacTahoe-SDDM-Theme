#!/usr/bin/env bash
set -euo pipefail

THEME_NAME="MacTahoe-SDDM-Theme"
INSTALL_DIR="/usr/share/sddm/themes/${THEME_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDDM_CONF="/etc/sddm.conf"
SDDM_CONFD="/etc/sddm.conf.d"
THEME_CONF="${SDDM_CONFD}/10-theme.conf"

# -- pretty output --
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e " ${BLUE}::${NC} $*"; }
ok()    { echo -e " ${GREEN}✓${NC} $*"; }
warn()  { echo -e " ${YELLOW}!${NC} $*"; }
err()   { echo -e " ${RED}✗${NC} $*"; }
ask()   { echo -en " ${YELLOW}?${NC} $* ${DIM}[Y/n]${NC} "; }

confirm() {
    ask "$@"
    read -r ans
    [[ -z "$ans" || "$ans" =~ ^[Yy] ]]
}

# -- detect package manager --
pkg_install() {
    if command -v pacman &>/dev/null; then
        sudo pacman -S --needed --noconfirm "$@"
    elif command -v apt &>/dev/null; then
        sudo apt install -y "$@"
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y "$@"
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y "$@"
    elif command -v xbps-install &>/dev/null; then
        sudo xbps-install -Sy "$@"
    else
        err "Could not detect package manager. Please install manually: $*"
        return 1
    fi
}

pkg_name() {
    # map generic dep names to distro package names
    local dep="$1"
    if command -v pacman &>/dev/null; then
        case "$dep" in
            qsb)       echo "qt6-shadertools" ;;
            weston)    echo "weston" ;;
            sddm)     echo "sddm" ;;
            *)         echo "$dep" ;;
        esac
    elif command -v apt &>/dev/null; then
        case "$dep" in
            qsb)       echo "qt6-shader-baker" ;;
            weston)    echo "weston" ;;
            sddm)     echo "sddm" ;;
            *)         echo "$dep" ;;
        esac
    elif command -v dnf &>/dev/null; then
        case "$dep" in
            qsb)       echo "qt6-qtshadertools" ;;
            weston)    echo "weston" ;;
            sddm)     echo "sddm" ;;
            *)         echo "$dep" ;;
        esac
    else
        echo "$dep"
    fi
}

usage() {
    cat <<EOF

  ${BOLD}MacTahoe SDDM Theme${NC} — installer

  ${BOLD}Usage:${NC}
    ./install.sh              Install the theme
    ./install.sh --test       Preview in test mode (no root needed)
    ./install.sh --uninstall  Remove the theme and reset SDDM config
    ./install.sh --help       Show this help

EOF
}

# ──────────────────────────────────────────────────────────────
# -- help --
# ──────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

# ──────────────────────────────────────────────────────────────
# -- test mode --
# ──────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--test" || "${1:-}" == "-t" ]]; then
    info "Launching theme preview..."
    if ! command -v sddm-greeter-qt6 &>/dev/null; then
        err "sddm-greeter-qt6 not found. Is SDDM installed?"
        exit 1
    fi
    sddm-greeter-qt6 --test-mode --theme "${SCRIPT_DIR}"
    exit 0
fi

# ──────────────────────────────────────────────────────────────
# -- uninstall --
# ──────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--uninstall" || "${1:-}" == "-u" ]]; then
    echo
    info "Uninstalling ${THEME_NAME}..."
    if [[ -d "${INSTALL_DIR}" ]]; then
        sudo rm -rf "${INSTALL_DIR}"
        ok "Removed ${INSTALL_DIR}"
    else
        warn "Theme directory not found, skipping."
    fi
    [[ -f "${THEME_CONF}" ]] && sudo rm -f "${THEME_CONF}" && ok "Removed ${THEME_CONF}"
    if [[ -f "${SDDM_CONF}" ]] && grep -q "Current=${THEME_NAME}" "${SDDM_CONF}"; then
        sudo sed -i "s/^Current=${THEME_NAME}/Current=/" "${SDDM_CONF}"
        ok "Cleared theme from ${SDDM_CONF}"
    fi
    # clean up display server config we may have written
    [[ -f "${SDDM_CONFD}/10-display.conf" ]] && sudo rm -f "${SDDM_CONFD}/10-display.conf" && ok "Removed display server config"
    echo
    ok "Uninstalled successfully."
    echo
    exit 0
fi

# ──────────────────────────────────────────────────────────────
# -- install --
# ──────────────────────────────────────────────────────────────
echo
echo -e "  ${BOLD}MacTahoe SDDM Theme${NC} — installer"
echo

# 1. check sddm is installed
if ! command -v sddm &>/dev/null; then
    err "SDDM is not installed."
    if confirm "Install sddm?"; then
        pkg_install "$(pkg_name sddm)"
    else
        err "Cannot continue without SDDM."
        exit 1
    fi
fi
ok "SDDM found"

# 2. detect & compile shaders
info "Searching for QSB (Qt shader compiler)..."
QSB=""
for candidate in qsb qsb-qt6; do
    if command -v "$candidate" &>/dev/null; then
        QSB="$(command -v "$candidate")"
        break
    fi
done
# check common lib paths if not in PATH
if [[ -z "$QSB" ]]; then
    for p in /usr/lib/qt6/bin/qsb /usr/lib64/qt6/bin/qsb /usr/lib/qt6/libexec/qsb; do
        if [[ -x "$p" ]]; then
            QSB="$p"
            break
        fi
    done
fi

if [[ -n "$QSB" ]]; then
    ok "Found qsb: ${QSB}"
    info "Compiling shaders..."
    "$QSB" --qt6 -o "${SCRIPT_DIR}/liquidglass.frag.qsb" "${SCRIPT_DIR}/liquidglass.frag"
    "$QSB" --qt6 -o "${SCRIPT_DIR}/contourglow.frag.qsb" "${SCRIPT_DIR}/contourglow.frag"
    ok "Shaders compiled"
else
    warn "qsb not found — using precompiled .qsb shaders if present."
    if [[ ! -f "${SCRIPT_DIR}/liquidglass.frag.qsb" || ! -f "${SCRIPT_DIR}/contourglow.frag.qsb" ]]; then
        err "Precompiled shaders not found either!"
        if confirm "Install qt6-shadertools to compile them?"; then
            pkg_install "$(pkg_name qsb)"
            # retry
            QSB=$(command -v qsb || command -v qsb-qt6 || echo "")
            if [[ -n "$QSB" ]]; then
                "$QSB" --qt6 -o "${SCRIPT_DIR}/liquidglass.frag.qsb" "${SCRIPT_DIR}/liquidglass.frag"
                "$QSB" --qt6 -o "${SCRIPT_DIR}/contourglow.frag.qsb" "${SCRIPT_DIR}/contourglow.frag"
                ok "Shaders compiled"
            else
                err "qsb still not found after install. The theme will show fallback rectangles."
            fi
        else
            warn "Continuing without shaders — glass effects will be replaced with plain panels."
        fi
    else
        ok "Using precompiled shaders"
    fi
fi

# 3. copy theme files
info "Installing theme to ${INSTALL_DIR}..."
sudo mkdir -p "${INSTALL_DIR}"

THEME_FILES=(Main.qml Glass.qml ContourGlow.qml Glyph.qml metadata.desktop theme.conf)
for f in "${THEME_FILES[@]}"; do
    if [[ -f "${SCRIPT_DIR}/${f}" ]]; then
        sudo cp "${SCRIPT_DIR}/${f}" "${INSTALL_DIR}/"
    else
        err "Missing theme file: ${f}"
        exit 1
    fi
done

# copy optional assets
for f in liquidglass.frag.qsb contourglow.frag.qsb background.jpg preview.png; do
    [[ -f "${SCRIPT_DIR}/${f}" ]] && sudo cp "${SCRIPT_DIR}/${f}" "${INSTALL_DIR}/"
done

# permissions
sudo chown -R root:root "${INSTALL_DIR}"
sudo chmod -R 755 "${INSTALL_DIR}"
find "${INSTALL_DIR}" -type f -exec sudo chmod 644 {} +
ok "Theme files installed"

# 4. configure display server
info "Configuring SDDM display server..."
echo

DISPLAY_SERVER=""

# check if wayland compositor is available for sddm
HAS_WESTON=false
HAS_KWIN=false
command -v weston &>/dev/null && HAS_WESTON=true
command -v kwin_wayland &>/dev/null && HAS_KWIN=true

if $HAS_WESTON || $HAS_KWIN; then
    # wayland compositor is available — offer wayland or x11
    echo -e "  ${BOLD}Display server options:${NC}"
    echo
    echo -e "    ${BOLD}1)${NC} Wayland ${DIM}(recommended — smoother, better HiDPI)${NC}"
    echo -e "    ${BOLD}2)${NC} X11     ${DIM}(more compatible, works everywhere)${NC}"
    echo
    echo -en "  ${YELLOW}?${NC} Choose [1/2, default=1]: "
    read -r ds_choice
    case "${ds_choice}" in
        2) DISPLAY_SERVER="x11-user" ;;
        *) DISPLAY_SERVER="wayland" ;;
    esac
else
    # no wayland compositor available
    warn "No Wayland compositor found for SDDM greeter."
    echo
    echo -e "  SDDM needs a compositor like ${BOLD}weston${NC} to run its greeter in Wayland mode."
    echo -e "  Without it, SDDM falls back to X11 which adds boot delay."
    echo
    if confirm "Install weston for Wayland greeter support?"; then
        pkg_install "$(pkg_name weston)"
        if command -v weston &>/dev/null; then
            ok "weston installed"
            HAS_WESTON=true
            DISPLAY_SERVER="wayland"
        else
            warn "weston install failed, using X11."
            DISPLAY_SERVER="x11-user"
        fi
    else
        DISPLAY_SERVER="x11-user"
    fi
fi

# build the compositor command
COMPOSITOR_CMD=""
if [[ "$DISPLAY_SERVER" == "wayland" ]]; then
    if $HAS_KWIN; then
        COMPOSITOR_CMD="kwin_wayland --no-lockscreen --no-global-shortcuts"
    elif $HAS_WESTON; then
        COMPOSITOR_CMD="weston --shell=kiosk"
    fi
fi

ok "Display server: ${DISPLAY_SERVER}"

# 5. write sddm config
info "Writing SDDM configuration..."
sudo mkdir -p "${SDDM_CONFD}"

# theme config
cat <<CONF | sudo tee "${THEME_CONF}" > /dev/null
[Theme]
Current=${THEME_NAME}
CONF

# display server config
if [[ "$DISPLAY_SERVER" == "wayland" ]]; then
    cat <<CONF | sudo tee "${SDDM_CONFD}/10-display.conf" > /dev/null
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
MinimumVT=1

[Wayland]
CompositorCommand=${COMPOSITOR_CMD}
CONF
else
    cat <<CONF | sudo tee "${SDDM_CONFD}/10-display.conf" > /dev/null
[General]
DisplayServer=x11-user
MinimumVT=1
CONF
fi

# sync /etc/sddm.conf if it exists to prevent conflicts
if [[ -f "${SDDM_CONF}" ]]; then
    # update theme
    if grep -q "^Current=" "${SDDM_CONF}"; then
        sudo sed -i "s/^Current=.*/Current=${THEME_NAME}/" "${SDDM_CONF}"
    fi
    # update display server
    if grep -q "^DisplayServer=" "${SDDM_CONF}"; then
        sudo sed -i "s/^DisplayServer=.*/DisplayServer=${DISPLAY_SERVER}/" "${SDDM_CONF}"
    fi
    # update compositor command if wayland
    if [[ "$DISPLAY_SERVER" == "wayland" ]] && [[ -n "$COMPOSITOR_CMD" ]]; then
        if grep -q "^CompositorCommand=" "${SDDM_CONF}"; then
            sudo sed -i "s|^CompositorCommand=.*|CompositorCommand=${COMPOSITOR_CMD}|" "${SDDM_CONF}"
        fi
    fi
    # update greeter env
    if grep -q "^GreeterEnvironment=" "${SDDM_CONF}"; then
        if [[ "$DISPLAY_SERVER" == "wayland" ]]; then
            sudo sed -i "s/^GreeterEnvironment=.*/GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell/" "${SDDM_CONF}"
        else
            sudo sed -i "s/^GreeterEnvironment=.*/GreeterEnvironment=/" "${SDDM_CONF}"
        fi
    fi
fi
ok "SDDM configured"

# 6. enable sddm service if not already
if command -v systemctl &>/dev/null; then
    if ! systemctl is-enabled sddm.service &>/dev/null; then
        if confirm "Enable SDDM service to start on boot?"; then
            sudo systemctl enable sddm.service
            ok "SDDM service enabled"
        fi
    fi
fi

# 7. done!
echo
echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}✓${NC} ${BOLD}${THEME_NAME} installed successfully!${NC}"
echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "  ${DIM}Preview:${NC}  ./install.sh --test"
echo -e "  ${DIM}Remove:${NC}   ./install.sh --uninstall"
echo
