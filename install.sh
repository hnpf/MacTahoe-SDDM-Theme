cat << 'EOF' > install.sh
#!/usr/bin/env bash
set -e

THEME_NAME="MacTahoe-SDDM-Theme"
INSTALL_DIR="/usr/share/sddm/themes/${THEME_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "$[{BLUE}==>${NC}] Setting up ${THEME_NAME}..."

# flag: --test
if [[ "$1" == "--test" || "$1" == "-t" ]]; then
    echo -e "$[{GREEN}==>${NC}] Starting preview..."
    sddm-greeter-qt6 --test-mode --theme "${SCRIPT_DIR}"
    exit 0
fi

# flag: --uninstall
if [[ "$1" == "--uninstall" || "$1" == "-u" ]]; then
    echo -e "$[{RED}==>${NC}] Removing ${THEME_NAME} from ${INSTALL_DIR}..."
    sudo rm -rf "${INSTALL_DIR}"
    echo -e "$[{GREEN}==>${NC}] Uninstalled successfully!"
    exit 0
fi

# detect & compile shaders with qsb
echo -e "$[{BLUE}==>${NC}] Searching for QSB binaries..."
QSB=$(command -v qsb || command -v qsb-qt6 || ls /usr/lib*/qt6/bin/qsb 2>/dev/null | head -n 1)

if [ -n "$QSB" ]; then
    echo -e "$[{GREEN}x${NC}] Found qsb at: ${QSB}"
    echo -e "$[{BLUE}==>${NC}] Compiling Liquid Glass shaders..."
    "$QSB" --qt6 -o "${SCRIPT_DIR}/liquidglass.frag.qsb" "${SCRIPT_DIR}/liquidglass.frag"
    "$QSB" --qt6 -o "${SCRIPT_DIR}/contourglow.frag.qsb" "${SCRIPT_DIR}/contourglow.frag"
    echo -e "$[{GREEN}x${NC}] Shaders compiled."
else
    echo -e "$[{RED}!${NC}] Warning: qsb was not found. fallback ot precompiled .qsb shaders if present!"
fi

# install
echo -e "$[{BLUE}==>${NC}] installing theme to ${INSTALL_DIR}..."
sudo mkdir -p "${INSTALL_DIR}"
sudo cp -r "${SCRIPT_DIR}"/{Main.qml,Glass.qml,ContourGlow.qml,Glyph.qml,metadata.desktop,theme.conf} "${INSTALL_DIR}/"

# copy shaders & assets / if present
for file in liquidglass.frag.qsb contourglow.frag.qsb background.jpg preview.png; do
    if [ -f "${SCRIPT_DIR}/${file}" ]; then
        sudo cp "${SCRIPT_DIR}/${file}" "${INSTALL_DIR}/"
    fi
done

# make sddm use MacTahoe-SDDM-Theme
echo -e "$[{BLUE}==>${NC}] Applying SDDM configuration..."
sudo mkdir -p /etc/sddm.conf.d/
cat << CONF | sudo tee /etc/sddm.conf.d/10-theme.conf > /dev/null
[Theme]
Current=${THEME_NAME}
CONF

echo -e "$[{GREEN}==>${NC}] ${THEME_NAME} has installed successfully!"
echo -e "test theme by running: ${BLUE}./install.sh --test${NC}"
EOF

chmod +x install.sh