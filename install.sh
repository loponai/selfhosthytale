#!/usr/bin/env bash
# =============================================================================
# Hytale One-Shot Server Installer
# Inspired by https://github.com/loponai/oneshotmatrix
#
# Deploys a dedicated Hytale server on a fresh Ubuntu/Debian VPS in one command:
#   curl -fsSL https://YOUR_URL/install.sh | sudo bash
#
# Tested on: Ubuntu 22.04, 24.04 | Debian 12
# Requires:  Root access, 4GB+ RAM, x64 or arm64
# =============================================================================

set -euo pipefail

# --- Colors & Helpers --------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

LOG_FILE="/var/log/hytale-install.log"

info()    { echo -e "${CYAN}[INFO]${NC} $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[OK]${NC} $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"; exit 1; }

# --- Pre-flight Checks -------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Use: sudo bash install.sh"
fi

if ! command -v apt &>/dev/null; then
    error "This script requires a Debian/Ubuntu-based system (apt package manager)."
fi

ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
    error "Unsupported architecture: $ARCH. Hytale requires x64 or arm64."
fi

TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
if [[ $TOTAL_RAM_MB -lt 3500 ]]; then
    warn "System has ${TOTAL_RAM_MB}MB RAM. Hytale recommends at least 4GB."
    warn "The server may not run well. Continue anyway? (y/N)"
    read -r -t 60 CONTINUE || CONTINUE="N"
    [[ "$CONTINUE" =~ ^[Yy]$ ]] || exit 1
fi

# --- Configuration Prompts ----------------------------------------------------

INSTALL_DIR="/opt/hytale"
SERVER_DIR="${INSTALL_DIR}/server"
BACKUP_DIR="${INSTALL_DIR}/backups"
SERVICE_NAME="hytale-server"
HYTALE_USER="hytale"

echo ""
echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}   Hytale One-Shot Server Installer${NC}"
echo -e "${BOLD}============================================${NC}"
echo ""

# Memory allocation
DEFAULT_MEM=$(( TOTAL_RAM_MB * 75 / 100 / 1024 ))
[[ $DEFAULT_MEM -lt 4 ]] && DEFAULT_MEM=4
echo -e "${CYAN}How much memory (in GB) to allocate to the Hytale server?${NC}"
echo -e "  Your VPS has ${TOTAL_RAM_MB}MB total RAM."
echo -e "  Recommended: ~75% of total = ${DEFAULT_MEM}G"
read -r -t 60 -p "  Memory [${DEFAULT_MEM}G]: " SERVER_MEM || SERVER_MEM=""
SERVER_MEM=${SERVER_MEM:-${DEFAULT_MEM}G}
# Normalize: handle G, g, M, m
SERVER_MEM=$(echo "$SERVER_MEM" | tr '[:lower:]' '[:upper:]')
if [[ "$SERVER_MEM" =~ ^[0-9]+M$ ]]; then
    MB_VALUE="${SERVER_MEM%M}"
    SERVER_MEM="$(( MB_VALUE / 1024 ))G"
elif [[ "$SERVER_MEM" =~ ^[0-9]+G?$ ]]; then
    SERVER_MEM="${SERVER_MEM%G}G"
else
    error "Invalid memory format '${SERVER_MEM}'. Use format like: 4G or 4096M"
fi

# Port
echo ""
echo -e "${CYAN}Which UDP port should the server listen on?${NC}"
read -r -t 60 -p "  Port [5520]: " SERVER_PORT || SERVER_PORT=""
SERVER_PORT=${SERVER_PORT:-5520}
# Validate port number
if ! [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] || [[ "$SERVER_PORT" -lt 1 ]] || [[ "$SERVER_PORT" -gt 65535 ]]; then
    error "Invalid port number '${SERVER_PORT}'. Must be between 1 and 65535."
fi
if [[ "$SERVER_PORT" -lt 1024 ]]; then
    warn "Port ${SERVER_PORT} is a privileged port (<1024). This may require additional configuration."
fi

# Backups
echo ""
echo -e "${CYAN}Enable automatic backups every 30 minutes?${NC}"
read -r -t 60 -p "  Enable backups? [Y/n]: " ENABLE_BACKUPS || ENABLE_BACKUPS=""
ENABLE_BACKUPS=${ENABLE_BACKUPS:-Y}

echo ""
info "Starting installation..."
info "Install log: ${LOG_FILE}"
echo ""

# --- Step 1: System Update ----------------------------------------------------

info "Updating system packages..."
apt update -q
apt upgrade -y -q
success "System updated."

# --- Step 2: Install Dependencies ---------------------------------------------

info "Installing dependencies..."
apt install -y -q wget curl gpg apt-transport-https lsb-release tar gzip ufw cron
success "Dependencies installed."

# --- Step 3: Install Java 25 (Adoptium Temurin) --------------------------------

info "Installing Java 25 (Eclipse Temurin)..."

if java --version 2>&1 | grep -qE "openjdk 25\."; then
    success "Java 25 already installed, skipping."
else
    # Add Adoptium GPG key and repository
    mkdir -p /etc/apt/keyrings
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
        | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg

    # Detect distro codename robustly (works on both Ubuntu and Debian)
    CODENAME=""
    if command -v lsb_release &>/dev/null; then
        CODENAME=$(lsb_release -cs 2>/dev/null || true)
    fi
    if [[ -z "$CODENAME" ]] && [[ -f /etc/os-release ]]; then
        CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
    fi
    if [[ -z "$CODENAME" ]]; then
        warn "Could not detect distro codename, defaulting to 'jammy' (Ubuntu 22.04)."
        CODENAME="jammy"
    fi
    info "Using distro codename: ${CODENAME}"

    echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb ${CODENAME} main" \
        > /etc/apt/sources.list.d/adoptium.list

    apt update -q
    apt install -y -q temurin-25-jdk

    if ! java --version 2>&1 | grep -qE "openjdk 25\."; then
        error "Java 25 installation failed. Check the Adoptium repository for your distro (${CODENAME})."
    fi

    success "Java 25 installed."
fi

# --- Step 4: Create Hytale User -----------------------------------------------

info "Creating '${HYTALE_USER}' system user..."

if id "$HYTALE_USER" &>/dev/null; then
    success "User '${HYTALE_USER}' already exists, skipping."
else
    useradd -r -m -d "$INSTALL_DIR" -s /bin/bash "$HYTALE_USER"
    success "User '${HYTALE_USER}' created."
fi

# --- Step 5: Download Hytale Server -------------------------------------------

info "Setting up server directory..."
mkdir -p "$SERVER_DIR" "$BACKUP_DIR"

info "Downloading Hytale Downloader CLI..."
cd "$SERVER_DIR"

# Determine downloader filename based on architecture
if [[ "$ARCH" == "x86_64" ]]; then
    DOWNLOADER_ARCH="linux-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    DOWNLOADER_ARCH="linux-arm64"
fi

DOWNLOADER_URL="https://downloader.hytale.com/hytale-downloader.zip"
DOWNLOADER_BIN="hytale-downloader-${DOWNLOADER_ARCH}"

if [[ -f "${SERVER_DIR}/${DOWNLOADER_BIN}" ]]; then
    warn "Hytale Downloader already exists. Checking for updates..."
    chown -R "${HYTALE_USER}:${HYTALE_USER}" "$INSTALL_DIR"
    su - "$HYTALE_USER" -c "cd ${SERVER_DIR} && ./${DOWNLOADER_BIN} -check-update" || warn "Update check failed (non-fatal)."
else
    info "Downloading from: ${DOWNLOADER_URL}"
    wget -q --show-progress -O hytale-downloader.zip "$DOWNLOADER_URL" || {
        warn "Automatic download failed."
        warn "You may need to download the Hytale Downloader manually from hytale.com"
        warn "Place it in: ${SERVER_DIR}/"
        warn "The script will continue setting up everything else."
    }

    if [[ -f "hytale-downloader.zip" ]]; then
        apt install -y -q unzip >/dev/null 2>&1 || true
        unzip -o hytale-downloader.zip
        rm -f hytale-downloader.zip
        chmod +x "${DOWNLOADER_BIN}" 2>/dev/null || true
        # Create a convenience symlink
        ln -sf "${DOWNLOADER_BIN}" hytale-downloader
        success "Hytale Downloader extracted."
    fi
fi

# Set ownership
chown -R "${HYTALE_USER}:${HYTALE_USER}" "$INSTALL_DIR"

# Run the downloader to fetch server files
if [[ -x "${SERVER_DIR}/${DOWNLOADER_BIN}" ]] || [[ -x "${SERVER_DIR}/hytale-downloader" ]]; then
    info "Downloading Hytale server files (this may take a few minutes)..."
    su - "$HYTALE_USER" -c "cd ${SERVER_DIR} && ./${DOWNLOADER_BIN}" || {
        warn "Downloader exited with an error. You may need to run it manually after install."
        warn "  su - ${HYTALE_USER}"
        warn "  cd ${SERVER_DIR} && ./${DOWNLOADER_BIN}"
    }
    success "Server files downloaded."
fi

# --- Step 6: Configure Firewall -----------------------------------------------

info "Configuring firewall (UFW)..."

ufw allow 22/tcp comment "SSH" >/dev/null 2>&1 || true
ufw allow "${SERVER_PORT}/udp" comment "Hytale Server" >/dev/null 2>&1 || true

if ! ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw --force enable >/dev/null 2>&1 || true
fi

success "Firewall configured: SSH (22/tcp) and Hytale (${SERVER_PORT}/udp) allowed."

# --- Step 7: Create systemd Service -------------------------------------------

info "Creating systemd service..."

BIND_FLAG=""
if [[ "$SERVER_PORT" != "5520" ]]; then
    BIND_FLAG=" --bind 0.0.0.0:${SERVER_PORT}"
fi

cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Hytale Dedicated Server
After=network.target

[Service]
Type=simple
User=${HYTALE_USER}
Group=${HYTALE_USER}
WorkingDirectory=${SERVER_DIR}
ExecStart=/usr/bin/java -Xms${SERVER_MEM} -Xmx${SERVER_MEM} -jar HytaleServer.jar --assets Assets.zip${BIND_FLAG}
ExecStop=/bin/kill -SIGINT \$MAINPID
Restart=on-failure
RestartSec=10
TimeoutStopSec=120
KillMode=mixed
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${SERVER_DIR} ${BACKUP_DIR}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME" >/dev/null 2>&1

success "systemd service '${SERVICE_NAME}' created and enabled."

# --- Step 8: Setup Backups -----------------------------------------------------

if [[ "$ENABLE_BACKUPS" =~ ^[Yy]$ ]]; then
    info "Setting up automatic backups..."

    BACKUP_SCRIPT="${INSTALL_DIR}/backup.sh"
    cat > "$BACKUP_SCRIPT" << BACKUPEOF
#!/usr/bin/env bash
# Hytale Server Backup Script (auto-generated by installer)
BACKUP_DIR="${BACKUP_DIR}"
SERVER_DIR="${SERVER_DIR}"
TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="\${BACKUP_DIR}/hytale-backup-\${TIMESTAMP}.tar.gz"

mkdir -p "\$BACKUP_DIR"

# Only back up if there is data to back up
if [[ -d "\${SERVER_DIR}/universe" ]] || [[ -f "\${SERVER_DIR}/config.json" ]]; then
    tar -czf "\$BACKUP_FILE" \\
        -C "\$SERVER_DIR" \\
        universe/ config.json permissions.json whitelist.json bans.json \\
        2>/dev/null || true

    # Keep only the last 48 backups (24 hours at 30-min intervals)
    find "\${BACKUP_DIR}" -name "hytale-backup-*.tar.gz" -mtime +1 -delete 2>/dev/null || true
fi
BACKUPEOF

    chmod +x "$BACKUP_SCRIPT"
    chown "${HYTALE_USER}:${HYTALE_USER}" "$BACKUP_SCRIPT"

    # Add cron job (every 30 minutes) — idempotent via temp file
    CRON_LINE="*/30 * * * * ${BACKUP_SCRIPT}"
    TEMP_CRON=$(mktemp)
    (crontab -u "$HYTALE_USER" -l 2>/dev/null || true) | grep -vF "$BACKUP_SCRIPT" > "$TEMP_CRON" || true
    echo "$CRON_LINE" >> "$TEMP_CRON"
    crontab -u "$HYTALE_USER" "$TEMP_CRON"
    rm -f "$TEMP_CRON"

    success "Backup cron job configured (every 30 minutes, keeps last 24 hours)."
fi

# --- Step 9: Create Helper Scripts --------------------------------------------

# Console helper (systemd-aware)
cat > "${INSTALL_DIR}/console.sh" << 'EOF'
#!/usr/bin/env bash
# View Hytale server console output
echo "Hytale server runs under systemd. Use these commands:"
echo ""
echo "  Live logs:     journalctl -u hytale-server -f"
echo "  Recent logs:   journalctl -u hytale-server --since '1 hour ago'"
echo "  Status:        systemctl status hytale-server"
echo "  Stop:          systemctl stop hytale-server"
echo "  Restart:       systemctl restart hytale-server"
echo ""
echo "Opening live logs now (Ctrl+C to exit)..."
echo ""
journalctl -u hytale-server -f
EOF
chmod +x "${INSTALL_DIR}/console.sh"

# Save install details for reference (oneshotmatrix pattern)
cat > "${INSTALL_DIR}/credentials.txt" << CREDEOF
============================================
  Hytale Server Install Details
  Generated: $(date)
============================================

Install directory:  ${SERVER_DIR}
Backup directory:   ${BACKUP_DIR}
Service name:       ${SERVICE_NAME}
Server port:        ${SERVER_PORT}/udp
Memory allocation:  ${SERVER_MEM}
System user:        ${HYTALE_USER}
Java version:       $(java --version 2>&1 | head -1)
OS:                 $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)

Commands:
  Start:    systemctl start ${SERVICE_NAME}
  Stop:     systemctl stop ${SERVICE_NAME}
  Restart:  systemctl restart ${SERVICE_NAME}
  Logs:     journalctl -u ${SERVICE_NAME} -f
  Status:   systemctl status ${SERVICE_NAME}
CREDEOF
chmod 600 "${INSTALL_DIR}/credentials.txt"
chown "${HYTALE_USER}:${HYTALE_USER}" "${INSTALL_DIR}/credentials.txt"

# --- Step 10: Start the Server -------------------------------------------------

info "Checking for server jar..."

if [[ -f "${SERVER_DIR}/HytaleServer.jar" ]]; then
    info "Starting Hytale server..."
    systemctl start "$SERVICE_NAME"
    sleep 3

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        success "Hytale server is running!"
    else
        warn "Server may have failed to start. Check logs with:"
        warn "  journalctl -u ${SERVICE_NAME} -n 50 --no-pager"
    fi
else
    warn "HytaleServer.jar not found in ${SERVER_DIR}."
    warn "You may need to run the Hytale Downloader manually:"
    warn "  su - ${HYTALE_USER}"
    warn "  cd ${SERVER_DIR}"
    warn "  ./${DOWNLOADER_BIN}"
    warn "Then start the server with: systemctl start ${SERVICE_NAME}"
fi

# --- Done! --------------------------------------------------------------------

PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "YOUR_VPS_IP")

echo ""
echo -e "${GREEN}${BOLD}============================================${NC}"
echo -e "${GREEN}${BOLD}  Hytale Server installed successfully!${NC}"
echo -e "${GREEN}${BOLD}============================================${NC}"
echo ""
echo -e "  ${BOLD}Install directory:${NC}  ${SERVER_DIR}"
echo -e "  ${BOLD}Backup directory:${NC}   ${BACKUP_DIR}"
echo -e "  ${BOLD}Service name:${NC}       ${SERVICE_NAME}"
echo -e "  ${BOLD}Port:${NC}               ${SERVER_PORT}/udp"
echo -e "  ${BOLD}Memory:${NC}             ${SERVER_MEM}"
echo -e "  ${BOLD}Java:${NC}               $(java --version 2>&1 | head -1)"
echo -e "  ${BOLD}Install log:${NC}        ${LOG_FILE}"
echo -e "  ${BOLD}Install details:${NC}    ${INSTALL_DIR}/credentials.txt"
echo ""
echo -e "  ${YELLOW}${BOLD}NEXT STEP: Authenticate your server!${NC}"
echo -e "  Run the server interactively to authenticate:"
echo ""
echo -e "    ${CYAN}systemctl stop ${SERVICE_NAME}${NC}"
echo -e "    ${CYAN}su - ${HYTALE_USER}${NC}"
echo -e "    ${CYAN}cd ${SERVER_DIR}${NC}"
echo -e "    ${CYAN}java -Xms${SERVER_MEM} -Xmx${SERVER_MEM} -jar HytaleServer.jar --assets Assets.zip${BIND_FLAG}${NC}"
echo ""
echo -e "  Then in the console, type:  ${BOLD}/auth login device${NC}"
echo -e "  Follow the URL at ${BOLD}https://accounts.hytale.com/device${NC}"
echo -e "  Enter the code shown in the console and sign in."
echo -e "  After auth succeeds, run:   ${BOLD}/auth persistence Encrypted${NC}"
echo -e "  Then Ctrl+C and restart the service:"
echo ""
echo -e "    ${CYAN}exit${NC}"
echo -e "    ${CYAN}systemctl start ${SERVICE_NAME}${NC}"
echo ""
echo -e "  ${BOLD}Useful commands:${NC}"
echo -e "    systemctl status ${SERVICE_NAME}    # Check status"
echo -e "    systemctl restart ${SERVICE_NAME}   # Restart"
echo -e "    journalctl -u ${SERVICE_NAME} -f    # Live logs"
echo ""
echo -e "${GREEN}${BOLD}============================================${NC}"
echo -e "  Players connect to: ${BOLD}${PUBLIC_IP}${NC}"
[[ "$SERVER_PORT" != "5520" ]] && echo -e "  Using custom port: ${BOLD}${SERVER_PORT}${NC}"
echo -e "${GREEN}${BOLD}============================================${NC}"
echo ""
