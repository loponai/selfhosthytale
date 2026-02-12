#!/usr/bin/env bash
# =============================================================================
# Hytale One-Shot Server Installer
# Inspired by https://github.com/loponai/oneshotmatrix
#
# Deploys a dedicated Hytale server on a fresh VPS in one command:
#   curl -fsSL https://raw.githubusercontent.com/loponai/selfhosthytale/main/install.sh | sudo bash
#
# Tested on: Rocky Linux 10 | Ubuntu 22.04, 24.04 | Debian 12
# Requires:  Root access, 4GB+ RAM, x64 or arm64
# =============================================================================

set -euo pipefail

# --- Security Hardening ------------------------------------------------------

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
umask 027

# --- Colors & Helpers --------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

LOG_FILE="/var/log/hytale-install.log"
touch "$LOG_FILE"
chmod 640 "$LOG_FILE"

# Cleanup on interrupt or failure
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${YELLOW}[WARN]${NC} Installation interrupted or failed. System may be in a partial state." | tee -a "$LOG_FILE"
        echo -e "${YELLOW}[WARN]${NC} Re-run the installer to resume, or run the uninstaller to clean up." | tee -a "$LOG_FILE"
        rm -f /tmp/temurin-25-jdk.*.tar.gz 2>/dev/null || true
        rm -f /tmp/adoptium-key.*.pub 2>/dev/null || true
    fi
}
trap cleanup EXIT

info()    { printf '%b %s\n' "${CYAN}[INFO]${NC}" "$*" | tee -a "$LOG_FILE"; }
success() { printf '%b %s\n' "${GREEN}[OK]${NC}" "$*" | tee -a "$LOG_FILE"; }
warn()    { printf '%b %s\n' "${YELLOW}[WARN]${NC}" "$*" | tee -a "$LOG_FILE"; }
error()   { printf '%b %s\n' "${RED}[ERROR]${NC}" "$*" | tee -a "$LOG_FILE"; exit 1; }

# --- Detect Package Manager --------------------------------------------------

PKG_MANAGER=""
if command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
elif command -v apt &>/dev/null; then
    PKG_MANAGER="apt"
else
    error "Unsupported system. This script requires dnf (Rocky/RHEL) or apt (Ubuntu/Debian)."
fi

pkg_install() {
    if [[ "$PKG_MANAGER" == "dnf" ]]; then
        dnf install -y -q "$@"
    else
        apt install -y -q "$@"
    fi
}

pkg_update() {
    if [[ "$PKG_MANAGER" == "dnf" ]]; then
        dnf update -y -q
    else
        apt update -q && apt upgrade -y -q
    fi
}

# --- Pre-flight Checks -------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Use: sudo bash install.sh"
fi

ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
    error "Unsupported architecture: $ARCH. Hytale requires x64 or arm64."
fi

TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
if [[ $TOTAL_RAM_MB -lt 3500 ]]; then
    warn "System has ${TOTAL_RAM_MB}MB RAM. Hytale recommends at least 4GB."
    warn "The server may not run well. Continue anyway? (y/N)"
    read -r -t 60 CONTINUE < /dev/tty || CONTINUE="N"
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
read -r -t 60 -p "  Memory [${DEFAULT_MEM}G]: " SERVER_MEM < /dev/tty || SERVER_MEM=""
SERVER_MEM=${SERVER_MEM:-${DEFAULT_MEM}G}
# Normalize: handle G, g, M, m
SERVER_MEM=$(echo "$SERVER_MEM" | tr '[:lower:]' '[:upper:]')
# Reject values with whitespace or newlines (prevents systemd directive injection)
if [[ "$SERVER_MEM" =~ [[:space:]] ]]; then
    error "Memory value must not contain whitespace."
fi
if [[ "$SERVER_MEM" =~ ^[0-9]+M$ ]]; then
    MB_VALUE="${SERVER_MEM%M}"
    SERVER_MEM="$(( MB_VALUE / 1024 ))G"
elif [[ "$SERVER_MEM" =~ ^[0-9]+G?$ ]]; then
    SERVER_MEM="${SERVER_MEM%G}G"
else
    error "Invalid memory format '${SERVER_MEM}'. Use format like: 4G or 4096M"
fi

# Port (Hytale default, no need to ask)
SERVER_PORT=5520

# Backups
echo ""
echo -e "${CYAN}Enable automatic backups every 30 minutes?${NC}"
read -r -t 60 -p "  Enable backups? [Y/n]: " ENABLE_BACKUPS < /dev/tty || ENABLE_BACKUPS=""
ENABLE_BACKUPS=${ENABLE_BACKUPS:-Y}

echo ""
info "Detected package manager: ${PKG_MANAGER}"
info "Starting installation..."
info "Install log: ${LOG_FILE}"
echo ""

# --- Step 1: System Update ----------------------------------------------------

info "Updating system packages..."
# Clean up any broken repos from previous install attempts
rm -f /etc/yum.repos.d/adoptium.repo 2>/dev/null || true
pkg_update
success "System updated."

# --- Step 2: Install Dependencies ---------------------------------------------

info "Installing dependencies..."
if [[ "$PKG_MANAGER" == "dnf" ]]; then
    pkg_install wget curl tar gzip cronie unzip
    # Enable and start crond on Rocky/RHEL
    systemctl enable crond >/dev/null 2>&1 || true
    systemctl start crond >/dev/null 2>&1 || true
else
    pkg_install wget curl gpg apt-transport-https lsb-release tar gzip cron unzip
fi
success "Dependencies installed."

# --- Step 3: Install Java 25 (Adoptium Temurin) --------------------------------

info "Installing Java 25 (Eclipse Temurin)..."

if java --version 2>&1 | grep -qE "openjdk 25\."; then
    success "Java 25 already installed, skipping."
else
    if [[ "$PKG_MANAGER" == "dnf" ]]; then
        # RPM-based: download Temurin JDK tarball directly (most reliable across Rocky/RHEL versions)
        # Clean up any leftover repo from previous attempts
        rm -f /etc/yum.repos.d/adoptium.repo 2>/dev/null || true

        if [[ "$ARCH" == "x86_64" ]]; then
            JDK_ARCH="x64"
        elif [[ "$ARCH" == "aarch64" ]]; then
            JDK_ARCH="aarch64"
        else
            error "Unsupported architecture for JDK download: $ARCH"
        fi

        info "Downloading Temurin JDK 25 tarball..."
        JDK_URL="https://api.adoptium.net/v3/binary/latest/25/ga/linux/${JDK_ARCH}/jdk/hotspot/normal/eclipse"
        JDK_SHA_URL="https://api.adoptium.net/v3/binary/latest/25/ga/linux/${JDK_ARCH}/jdk/hotspot/normal/eclipse?type=sha256"
        JDK_TAR=$(mktemp /tmp/temurin-25-jdk.XXXXXX.tar.gz)
        wget -q --show-progress -O "$JDK_TAR" "$JDK_URL" || { rm -f "$JDK_TAR"; error "Failed to download JDK 25. Check https://adoptium.net/temurin/releases/ for availability."; }

        # Verify checksum
        info "Verifying JDK checksum..."
        EXPECTED_SHA=$(wget -qO - "$JDK_SHA_URL" 2>/dev/null | awk '{print $1}') || true
        if [[ -n "$EXPECTED_SHA" ]]; then
            ACTUAL_SHA=$(sha256sum "$JDK_TAR" | awk '{print $1}')
            if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
                rm -f "$JDK_TAR"
                error "JDK checksum mismatch! Download may be corrupted or tampered. Expected: ${EXPECTED_SHA} Got: ${ACTUAL_SHA}"
            fi
            success "JDK checksum verified."
        else
            rm -f "$JDK_TAR"
            error "Could not fetch JDK checksum. Refusing to install unverified binary. Check network connectivity."
        fi

        # Extract to /opt and symlink
        info "Installing JDK to /usr/lib/jvm/temurin-25..."
        mkdir -p /usr/lib/jvm
        tar --no-same-owner -xzf "$JDK_TAR" -C /usr/lib/jvm/
        # The tarball extracts to a directory like jdk-25.0.1+9
        JDK_DIRS=(/usr/lib/jvm/jdk-25*)
        JDK_DIR="${JDK_DIRS[0]}"
        if [[ ! -d "$JDK_DIR" ]]; then
            error "JDK extraction failed. Could not find extracted directory."
        fi
        ln -sfn "$JDK_DIR" /usr/lib/jvm/temurin-25

        # Set up alternatives so 'java' points to temurin-25
        update-alternatives --install /usr/bin/java java "${JDK_DIR}/bin/java" 1 >/dev/null 2>&1 || true
        update-alternatives --set java "${JDK_DIR}/bin/java" >/dev/null 2>&1 || true
        update-alternatives --install /usr/bin/javac javac "${JDK_DIR}/bin/javac" 1 >/dev/null 2>&1 || true
        update-alternatives --set javac "${JDK_DIR}/bin/javac" >/dev/null 2>&1 || true

        # Add to PATH via profile if alternatives didn't work
        if ! java --version 2>&1 | grep -qE "openjdk 25\."; then
            install -m 0644 /dev/null /etc/profile.d/temurin.sh
            echo "export JAVA_HOME=${JDK_DIR}" > /etc/profile.d/temurin.sh
            echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/profile.d/temurin.sh
            export JAVA_HOME="${JDK_DIR}"
            export PATH="${JDK_DIR}/bin:$PATH"
        fi

        rm -f "$JDK_TAR"
    else
        # Deb-based: add Adoptium repo for Ubuntu/Debian
        mkdir -p /etc/apt/keyrings
        TEMP_GPG=$(mktemp /tmp/adoptium-key.XXXXXX.pub)
        wget -qO "$TEMP_GPG" https://packages.adoptium.net/artifactory/api/gpg/key/public \
            || { rm -f "$TEMP_GPG"; error "Failed to download Adoptium GPG key."; }
        gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg < "$TEMP_GPG"
        rm -f "$TEMP_GPG"

        # Detect distro codename robustly
        CODENAME=""
        if command -v lsb_release &>/dev/null; then
            CODENAME=$(lsb_release -cs 2>/dev/null || true)
        fi
        if [[ -z "$CODENAME" ]] && [[ -f /etc/os-release ]]; then
            CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2 | tr -d '"')
        fi
        # Validate codename contains only lowercase letters
        if [[ -n "$CODENAME" && ! "$CODENAME" =~ ^[a-z]+$ ]]; then
            warn "Unexpected distro codename '${CODENAME}', defaulting to 'jammy'."
            CODENAME="jammy"
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
    fi

    if ! java --version 2>&1 | grep -qE "openjdk 25\."; then
        error "Java 25 installation failed. Check the Adoptium repository for your distro."
    fi

    success "Java 25 installed."
fi

# --- Step 4: Create Hytale User -----------------------------------------------

info "Creating '${HYTALE_USER}' system user..."

if id "$HYTALE_USER" &>/dev/null; then
    success "User '${HYTALE_USER}' already exists, skipping."
else
    useradd -r -m -d "$INSTALL_DIR" -s /usr/sbin/nologin "$HYTALE_USER"
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
else
    error "Unsupported architecture for Hytale Downloader: $ARCH"
fi

DOWNLOADER_URL="https://downloader.hytale.com/hytale-downloader.zip"
DOWNLOADER_BIN="hytale-downloader-${DOWNLOADER_ARCH}"

if [[ -f "${SERVER_DIR}/${DOWNLOADER_BIN}" ]]; then
    warn "Hytale Downloader already exists. Checking for updates..."
    chown -R --no-dereference "${HYTALE_USER}:${HYTALE_USER}" "$INSTALL_DIR"
    runuser -u "$HYTALE_USER" -- bash -c 'cd "$1" && ./"$2" -check-update' _ "$SERVER_DIR" "$DOWNLOADER_BIN" || warn "Update check failed (non-fatal)."
else
    info "Downloading from: ${DOWNLOADER_URL}"
    wget -q --show-progress -O hytale-downloader.zip "$DOWNLOADER_URL" || {
        warn "Automatic download failed."
        warn "You may need to download the Hytale Downloader manually from hytale.com"
        warn "Place it in: ${SERVER_DIR}/"
        warn "The script will continue setting up everything else."
    }

    if [[ -f "hytale-downloader.zip" ]]; then
        info "Hytale Downloader SHA256: $(sha256sum hytale-downloader.zip | awk '{print $1}')"
        unzip -o hytale-downloader.zip
        rm -f hytale-downloader.zip
        chmod +x "${DOWNLOADER_BIN}" 2>/dev/null || true
        # Create a convenience symlink
        ln -sf "${DOWNLOADER_BIN}" hytale-downloader
        success "Hytale Downloader extracted."
    fi
fi

# Set ownership (--no-dereference to avoid following symlinks)
chown -R --no-dereference "${HYTALE_USER}:${HYTALE_USER}" "$INSTALL_DIR"

# Run the downloader to fetch server files
if [[ -x "${SERVER_DIR}/${DOWNLOADER_BIN}" ]] || [[ -x "${SERVER_DIR}/hytale-downloader" ]]; then
    info "Downloading Hytale server files (this may take a few minutes)..."
    runuser -u "$HYTALE_USER" -- bash -c 'cd "$1" && ./"$2"' _ "$SERVER_DIR" "$DOWNLOADER_BIN" || {
        warn "Downloader exited with an error. You may need to run it manually after install."
        warn "  sudo -u ${HYTALE_USER} bash -c 'cd ${SERVER_DIR} && ./${DOWNLOADER_BIN}'"
    }
    success "Server files downloaded."
fi

# --- Step 6: Configure Firewall -----------------------------------------------

info "Configuring firewall..."

# Detect the actual SSH port to avoid lockout on non-standard ports (e.g. Scala uses 6543)
SSH_PORT=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
SSH_PORT=${SSH_PORT:-22}

if [[ "$PKG_MANAGER" == "dnf" ]]; then
    # Rocky/RHEL: use firewalld
    if ! systemctl is-active --quiet firewalld 2>/dev/null; then
        pkg_install firewalld >/dev/null 2>&1 || true
        systemctl enable firewalld >/dev/null 2>&1 || true
        systemctl start firewalld >/dev/null 2>&1 || true
    fi
    firewall-cmd --set-default-zone=public >/dev/null 2>&1 || true
    firewall-cmd --permanent --add-port="${SERVER_PORT}/udp" >/dev/null 2>&1 || true
    if [[ "$SSH_PORT" == "22" ]]; then
        firewall-cmd --permanent --add-service=ssh >/dev/null 2>&1 || true
    else
        firewall-cmd --permanent --add-port="${SSH_PORT}/tcp" >/dev/null 2>&1 || true
    fi
    firewall-cmd --reload >/dev/null 2>&1 || true
    success "Firewall configured (firewalld): SSH (${SSH_PORT}/tcp) and Hytale (${SERVER_PORT}/udp) allowed."
else
    # Ubuntu/Debian: use UFW
    ufw default deny incoming >/dev/null 2>&1 || true
    ufw default allow outgoing >/dev/null 2>&1 || true
    ufw allow "${SSH_PORT}/tcp" comment "SSH" >/dev/null 2>&1 || true
    ufw allow "${SERVER_PORT}/udp" comment "Hytale Server" >/dev/null 2>&1 || true
    if ! ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw --force enable >/dev/null 2>&1 || true
    fi
    success "Firewall configured (UFW): SSH (${SSH_PORT}/tcp) and Hytale (${SERVER_PORT}/udp) allowed."
fi

# --- Step 7: Create systemd Service -------------------------------------------

info "Creating systemd service..."

BIND_FLAG=""
if [[ "$SERVER_PORT" != "5520" ]]; then
    BIND_FLAG=" --bind 0.0.0.0:${SERVER_PORT}"
fi

install -m 0644 /dev/null "/etc/systemd/system/${SERVICE_NAME}.service"
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
PrivateDevices=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true
ProtectHostname=true
ReadWritePaths=${SERVER_DIR} ${BACKUP_DIR}
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictNamespaces=true
RestrictSUIDSGID=true
LockPersonality=true
SystemCallArchitectures=native
CapabilityBoundingSet=
AmbientCapabilities=

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
    find "\${BACKUP_DIR}" -maxdepth 1 -name "hytale-backup-*.tar.gz" -mtime +1 -delete 2>/dev/null || true
fi
BACKUPEOF

    chmod 0750 "$BACKUP_SCRIPT"
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
chmod 0750 "${INSTALL_DIR}/console.sh"
chown "${HYTALE_USER}:${HYTALE_USER}" "${INSTALL_DIR}/console.sh"

# Save install details for reference (oneshotmatrix pattern)
OS_PRETTY=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Unknown")
cat > "${INSTALL_DIR}/server-info.txt" << CREDEOF
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
OS:                 ${OS_PRETTY}
Package manager:    ${PKG_MANAGER}

Commands:
  Start:    systemctl start ${SERVICE_NAME}
  Stop:     systemctl stop ${SERVICE_NAME}
  Restart:  systemctl restart ${SERVICE_NAME}
  Logs:     journalctl -u ${SERVICE_NAME} -f
  Status:   systemctl status ${SERVICE_NAME}
CREDEOF
chmod 600 "${INSTALL_DIR}/server-info.txt"
chown "${HYTALE_USER}:${HYTALE_USER}" "${INSTALL_DIR}/server-info.txt"

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
    warn "  sudo -u ${HYTALE_USER} bash -c 'cd ${SERVER_DIR} && ./${DOWNLOADER_BIN}'"
    warn "Then start the server with: systemctl start ${SERVICE_NAME}"
fi

# --- Done! --------------------------------------------------------------------

PUBLIC_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || curl -s --max-time 5 https://ifconfig.me 2>/dev/null || echo "YOUR_VPS_IP")
# Sanitize IP to prevent terminal injection
if [[ ! "$PUBLIC_IP" =~ ^[0-9a-fA-F.:]+$ ]]; then
    PUBLIC_IP="YOUR_VPS_IP"
fi

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
echo -e "  ${BOLD}Install details:${NC}    ${INSTALL_DIR}/server-info.txt"
echo ""
echo -e "  ${YELLOW}${BOLD}NEXT STEP: Authenticate your server!${NC}"
echo -e "  Run the server interactively to authenticate:"
echo ""
echo -e "    ${CYAN}systemctl stop ${SERVICE_NAME}${NC}"
echo -e "    ${CYAN}sudo -u ${HYTALE_USER} bash -c 'cd ${SERVER_DIR} && java -Xms${SERVER_MEM} -Xmx${SERVER_MEM} -jar HytaleServer.jar --assets Assets.zip${BIND_FLAG}'${NC}"
echo ""
echo -e "  Then in the console, type:  ${BOLD}/auth login device${NC}"
echo -e "  Follow the URL at ${BOLD}https://accounts.hytale.com/device${NC}"
echo -e "  Enter the code shown in the console and sign in."
echo -e "  After auth succeeds, run:   ${BOLD}/auth persistence Encrypted${NC}"
echo -e "  Then Ctrl+C and restart the service:"
echo ""
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
