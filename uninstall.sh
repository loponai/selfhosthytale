#!/usr/bin/env bash
# =============================================================================
# Hytale Server Uninstaller
# Completely removes everything created by the one-shot installer.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/loponai/selfhosthytale/main/uninstall.sh | sudo bash
#
# =============================================================================

set -euo pipefail

# --- Colors & Helpers --------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- Pre-flight Checks -------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Use: sudo bash uninstall.sh"
fi

SERVICE_NAME="hytale-server"
HYTALE_USER="hytale"
INSTALL_DIR="/opt/hytale"

echo ""
echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}   Hytale Server Uninstaller${NC}"
echo -e "${BOLD}============================================${NC}"
echo ""
echo -e "${YELLOW}This will completely remove:${NC}"
echo "  - Hytale server files (${INSTALL_DIR})"
echo "  - systemd service (${SERVICE_NAME})"
echo "  - Backup cron job"
echo "  - '${HYTALE_USER}' system user"
echo "  - Firewall rules for port 5520/udp"
echo "  - Install log (/var/log/hytale-install.log)"
echo ""
echo -e "${RED}${BOLD}WARNING: All server data, world saves, and backups will be permanently deleted.${NC}"
echo ""
read -r -p "Are you sure you want to uninstall? Type 'yes' to confirm: " CONFIRM < /dev/tty || CONFIRM=""
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""

# --- Step 1: Stop and remove systemd service ----------------------------------

if systemctl list-unit-files "${SERVICE_NAME}.service" &>/dev/null; then
    info "Stopping ${SERVICE_NAME} service..."
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    systemctl daemon-reload
    success "systemd service removed."
else
    warn "Service '${SERVICE_NAME}' not found, skipping."
fi

# --- Step 2: Remove backup cron job -------------------------------------------

if id "$HYTALE_USER" &>/dev/null; then
    info "Removing backup cron job..."
    crontab -r -u "$HYTALE_USER" 2>/dev/null || true
    success "Cron job removed."
fi

# --- Step 3: Remove install directory -----------------------------------------

if [[ -d "$INSTALL_DIR" ]]; then
    info "Removing ${INSTALL_DIR}..."
    rm -rf "$INSTALL_DIR"
    success "Install directory removed."
else
    warn "${INSTALL_DIR} not found, skipping."
fi

# --- Step 4: Remove hytale system user ----------------------------------------

if id "$HYTALE_USER" &>/dev/null; then
    info "Removing '${HYTALE_USER}' system user..."
    userdel -r "$HYTALE_USER" 2>/dev/null || userdel "$HYTALE_USER" 2>/dev/null || true
    success "User '${HYTALE_USER}' removed."
else
    warn "User '${HYTALE_USER}' not found, skipping."
fi

# --- Step 5: Remove firewall rules -------------------------------------------

info "Removing firewall rules..."

if command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
    firewall-cmd --permanent --remove-port=5520/udp 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    success "Firewall rule removed (firewalld)."
elif command -v ufw &>/dev/null; then
    ufw delete allow 5520/udp 2>/dev/null || true
    success "Firewall rule removed (UFW)."
else
    warn "No firewall detected, skipping."
fi

# --- Step 6: Remove install log -----------------------------------------------

if [[ -f "/var/log/hytale-install.log" ]]; then
    rm -f /var/log/hytale-install.log
    success "Install log removed."
fi

# --- Step 7: Optionally remove Java ------------------------------------------

echo ""
echo -e "${CYAN}Do you also want to remove Java 25 (Eclipse Temurin)?${NC}"
echo "  If other applications use Java, you should keep it."
read -r -p "  Remove Java 25? [y/N]: " REMOVE_JAVA < /dev/tty || REMOVE_JAVA=""

if [[ "$REMOVE_JAVA" =~ ^[Yy]$ ]]; then
    info "Removing Java 25..."

    if command -v dnf &>/dev/null; then
        # Rocky/RHEL: remove tarball install
        rm -rf /usr/lib/jvm/temurin-25 /usr/lib/jvm/jdk-25*
        update-alternatives --remove java /usr/lib/jvm/temurin-25/bin/java 2>/dev/null || true
        update-alternatives --remove java /usr/lib/jvm/jdk-25*/bin/java 2>/dev/null || true
        update-alternatives --remove javac /usr/lib/jvm/temurin-25/bin/javac 2>/dev/null || true
        update-alternatives --remove javac /usr/lib/jvm/jdk-25*/bin/javac 2>/dev/null || true
        rm -f /etc/profile.d/temurin.sh
    elif command -v apt &>/dev/null; then
        # Ubuntu/Debian: remove package and repo
        apt remove -y temurin-25-jdk 2>/dev/null || true
        apt autoremove -y 2>/dev/null || true
        rm -f /etc/apt/sources.list.d/adoptium.list
        rm -f /etc/apt/keyrings/adoptium.gpg
    fi

    success "Java 25 removed."
else
    info "Keeping Java 25."
fi

# --- Done! --------------------------------------------------------------------

echo ""
echo -e "${GREEN}${BOLD}============================================${NC}"
echo -e "${GREEN}${BOLD}  Hytale Server uninstalled successfully!${NC}"
echo -e "${GREEN}${BOLD}============================================${NC}"
echo ""
echo "  Everything has been removed. Your VPS is back to a clean state."
echo ""
echo "  To reinstall, run:"
echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/loponai/selfhosthytale/main/install.sh | sudo bash${NC}"
echo ""
