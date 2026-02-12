# Self-Hosting a Hytale Server with Scala Hosting (One-Shot Setup)

A complete guide to deploying a dedicated Hytale server on a Scala Hosting VPS using a single automated install script.

---

## Table of Contents

1. [Requirements](#1-requirements)
2. [EULA & Server Operator Policies](#2-eula--server-operator-policies)
3. [Choosing a Scala Hosting VPS Plan](#3-choosing-a-scala-hosting-vps-plan)
4. [Ordering & Initial VPS Setup](#4-ordering--initial-vps-setup)
5. [Connecting to Your VPS via SSH](#5-connecting-to-your-vps-via-ssh)
6. [SSH Security Hardening](#6-ssh-security-hardening)
7. [One-Shot Automated Install](#7-one-shot-automated-install)
8. [Manual Setup (If You Prefer)](#8-manual-setup-if-you-prefer)
9. [Authenticating Your Server](#9-authenticating-your-server)
10. [Authentication Modes](#10-authentication-modes)
11. [Server Configuration](#11-server-configuration)
12. [Firewall & Port Forwarding](#12-firewall--port-forwarding)
13. [DNS & Domain Setup](#13-dns--domain-setup)
14. [Mods & Plugins](#14-mods--plugins)
15. [Managing Your Server](#15-managing-your-server)
16. [Backups](#16-backups)
17. [Performance Tuning](#17-performance-tuning)
18. [Updating Your Server](#18-updating-your-server)
19. [Troubleshooting](#19-troubleshooting)

---

## 1. Requirements

- **A Scala Hosting Self-Managed VPS** (see plan recommendations below)
- **A Hytale account** (needed for server authentication)
- **An SSH client** — Terminal (macOS/Linux) or [PuTTY](https://www.putty.org/) / Windows Terminal (Windows)
- **A domain name** (optional, but recommended for easy connection)

### Hytale Server System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **RAM** | 4 GB | 8 GB+ |
| **CPU** | 2 cores (x64 or arm64) | 4 cores, 3.5 GHz+ |
| **Storage** | 20 GB SSD | 50 GB+ NVMe |
| **Java** | Java 25 (Temurin/Adoptium) | Java 25 |
| **OS** | Ubuntu 22.04+ / Debian 12+ | Ubuntu 24.04 LTS |
| **Network** | UDP port 5520 open | Unmetered bandwidth |

---

## 2. EULA & Server Operator Policies

Before hosting a Hytale server, you **must** review and accept the following:

- [Hytale End-User License Agreement (EULA)](https://hytale.com/eula)
- [Server Operator Policies](https://hytale.com/server-policies)

### Key Points

- Operating a server constitutes acceptance of these terms.
- **Prohibited content:** sexual content, NFTs, crypto schemes, real-money gambling, pay-to-win mechanics.
- Server operators are responsible for all hosting costs, moderation, user content, and compliance with local laws.
- Hytale currently takes **0% commission** on server monetization for the first two years.
- There is a limit of **100 servers per Hytale game license**. Server providers hosting for others may need to apply for special accounts.

> Read the full policies before investing time in your server setup. Violations can result in your server being delisted or your account being banned.

---

## 3. Choosing a Scala Hosting VPS Plan

Go to [Scala Hosting Self-Managed VPS](https://www.scalahosting.com/linux-vps-hosting.html) and pick a **Self-Managed** plan. You need full root access — managed plans won't give you the control required.

| Plan | Price (Intro) | CPU | RAM | Storage | Best For |
|------|---------------|-----|-----|---------|----------|
| **Build #2** | ~$34–37/mo | 2 cores | 4 GB | 120 GB NVMe | 1–10 players (minimum viable) |
| **Build #3** | ~$52–67/mo | 4 cores | 8 GB | 240 GB NVMe | 10–30 players (recommended) |
| **Build #4** | ~$71–123/mo | 8 cores | 16 GB | 480 GB NVMe | 30–75+ players |

> **Pricing note:** Scala Hosting prices vary based on commitment length (1-month vs 1-year vs 3-year). The ranges above reflect this. **Renewal prices are higher than introductory rates.** Always check [the pricing page](https://www.scalahosting.com/linux-vps-hosting.html) for current rates before purchasing.

> **Recommendation:** Start with **Build #3** if you expect more than a handful of players. Hytale uses view-distance-based chunk loading which scales RAM usage quickly. You can always upgrade later through Scala's panel.

### Why Scala Hosting?

- **Full root access** on self-managed plans (required for Java, firewall, and service management)
- **KVM virtualization** — dedicated resources, no overselling
- **NVMe storage** — fast world loading and chunk I/O
- **Unmetered bandwidth** — no surprise overage charges
- **Free snapshots** — easy rollback if something goes wrong

---

## 4. Ordering & Initial VPS Setup

1. Go to [scalahosting.com/linux-vps-hosting.html](https://www.scalahosting.com/linux-vps-hosting.html)
2. Select your plan and click **Get Started**
3. Choose **Self-Managed** (not Managed with SPanel)
4. Select **Ubuntu 24.04 LTS** as your operating system
5. Choose your preferred data center location (pick one closest to your players)
6. Complete checkout

After provisioning (usually a few minutes), you'll receive an email with:
- Your VPS **IP address**
- **Root password**
- **SSH port** (usually 22)

---

## 5. Connecting to Your VPS via SSH

### Linux / macOS
```bash
ssh root@YOUR_VPS_IP
```

### Windows (PowerShell or Windows Terminal)
```powershell
ssh root@YOUR_VPS_IP
```

### Windows (PuTTY)
1. Open PuTTY
2. Enter your VPS IP in the **Host Name** field
3. Port: **22**
4. Click **Open**
5. Login as `root` with the password from your email

> **First-time tip:** You'll be asked to confirm the server fingerprint. Type `yes` to continue.

---

## 6. SSH Security Hardening

Your VPS is publicly accessible. Before installing anything else, harden SSH access to prevent brute-force attacks.

### 6.1 Create a Non-Root User

```bash
adduser gameadmin
usermod -aG sudo gameadmin
```

### 6.2 Set Up SSH Key Authentication

On your **local machine** (not the VPS):

```bash
# Generate a key pair (if you don't already have one)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy your public key to the VPS
ssh-copy-id gameadmin@YOUR_VPS_IP
```

Test that key-based login works:

```bash
ssh gameadmin@YOUR_VPS_IP
```

### 6.3 Disable Password Authentication

Once key-based login is confirmed working, disable password auth on the VPS:

```bash
sudo nano /etc/ssh/sshd_config
```

Find and set these values:

```
PasswordAuthentication no
PermitRootLogin prohibit-password
```

Restart SSH:

```bash
sudo systemctl restart sshd
```

### 6.4 Install fail2ban

fail2ban automatically blocks IPs after repeated failed login attempts:

```bash
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

The default configuration protects SSH out of the box. To check banned IPs:

```bash
sudo fail2ban-client status sshd
```

> **Important:** After these steps, always use `ssh gameadmin@YOUR_VPS_IP` to connect, then `sudo` for root commands. You can run the one-shot installer with `sudo bash install.sh`.

---

## 7. One-Shot Automated Install

Inspired by the [oneshotmatrix](https://github.com/loponai/oneshotmatrix) approach, this single command handles everything: system updates, Java 25 installation, Hytale server download, firewall configuration, and systemd service creation.

### Run the Installer

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/hytale-oneshot/main/install.sh | sudo bash
```

> **Or** if you cloned this repository to your VPS:
> ```bash
> cd /root
> git clone https://github.com/YOUR_REPO/hytale-oneshot.git
> cd hytale-oneshot
> chmod +x install.sh
> sudo ./install.sh
> ```

The script will prompt you for:
- **Server memory allocation** (default: 4G, recommended: match ~75% of your VPS RAM)
- **Server port** (default: 5520)
- **Enable automatic backups?** (default: yes, every 30 minutes)

### What the Script Does

1. Updates system packages (`apt update && apt upgrade`)
2. Installs Java 25 (Eclipse Temurin/Adoptium)
3. Creates a dedicated `hytale` system user
4. Downloads the Hytale Downloader CLI
5. Fetches the latest server files and assets
6. Configures UFW firewall (opens UDP 5520)
7. Creates a hardened systemd service (`hytale-server.service`) for auto-start on boot
8. Sets up a backup cron job
9. Saves install details to `/opt/hytale/credentials.txt`
10. Starts the server

After the script finishes, you'll see:

```
============================================
  Hytale Server installed successfully!
============================================
  Install directory:  /opt/hytale/server
  Service name:       hytale-server
  Port:               5520/udp
  Backup directory:   /opt/hytale/backups

  NEXT STEP: Authenticate your server!
  Then type: /auth login device
============================================
```

---

## 8. Manual Setup (If You Prefer)

If you'd rather do it step by step instead of using the one-shot script:

### 8.1 Update the System

```bash
apt update && apt upgrade -y
```

### 8.2 Install Java 25 (Adoptium Temurin)

```bash
# Add Adoptium repository
apt install -y wget apt-transport-https gpg lsb-release

mkdir -p /etc/apt/keyrings
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
    | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg

echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/adoptium.list

# Install Java 25
apt update
apt install -y temurin-25-jdk
```

Verify the installation:

```bash
java --version
# Should output: openjdk 25.x.x
```

### 8.3 Create a Dedicated User

```bash
useradd -r -m -d /opt/hytale -s /bin/bash hytale
```

### 8.4 Download Hytale Server Files

```bash
su - hytale
mkdir -p /opt/hytale/server
cd /opt/hytale/server

# Download the Hytale Downloader CLI
wget https://downloader.hytale.com/hytale-downloader.zip
apt install -y unzip  # if not already installed
unzip hytale-downloader.zip
chmod +x hytale-downloader-linux-amd64

# Download server files (requires OAuth authentication)
./hytale-downloader-linux-amd64
```

> **Note:** The downloader may prompt you to authenticate via `oauth.accounts.hytale.com`. Follow the on-screen instructions to complete the OAuth flow.

### 8.5 First Launch (Test Run)

```bash
java -Xms4G -Xmx4G -jar HytaleServer.jar --assets Assets.zip
```

The server will generate its config files and directories on first run. Stop it with `Ctrl+C` after it finishes loading.

### 8.6 Create a systemd Service

Switch back to root (`exit` from the hytale user), then create the service file:

```bash
cat > /etc/systemd/system/hytale-server.service << 'EOF'
[Unit]
Description=Hytale Dedicated Server
After=network.target

[Service]
User=hytale
Group=hytale
WorkingDirectory=/opt/hytale/server
ExecStart=/usr/bin/java -Xms4G -Xmx4G -jar HytaleServer.jar --assets Assets.zip
ExecStop=/bin/kill -SIGINT $MAINPID
Restart=on-failure
RestartSec=10
TimeoutStopSec=120
KillMode=mixed
StandardOutput=journal
StandardError=journal
SyslogIdentifier=hytale-server

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/hytale/server /opt/hytale/backups

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable hytale-server
systemctl start hytale-server
```

### 8.7 Open the Firewall

```bash
ufw allow 5520/udp comment "Hytale Server"
ufw allow 22/tcp comment "SSH"
ufw --force enable
```

---

## 9. Authenticating Your Server

Your server must be authenticated with a Hytale account before players can connect online.

### Stop the Service and Run Interactively

```bash
systemctl stop hytale-server
su - hytale
cd /opt/hytale/server
java -Xms4G -Xmx4G -jar HytaleServer.jar --assets Assets.zip
```

### Authenticate

In the server console, type:

```
/auth login device
```

The console will display:
1. A **URL**: `https://accounts.hytale.com/device`
2. A **code** (e.g., `ABCD-1234`)

Open the URL in your browser, enter the code, and sign in with your Hytale account. You should see **"Authentication successful!"** in the server console.

### Persist Authentication

To ensure authentication survives restarts, run:

```
/auth persistence Encrypted
```

This saves your credentials in an encrypted format so you don't need to re-authenticate after every reboot.

### Restart via systemd

After authenticating, stop the interactive server (`Ctrl+C`) and switch back to the service:

```bash
exit  # back to root
systemctl start hytale-server
```

> **Note:** Authentication persists across restarts once encrypted persistence is enabled. You only need to repeat this process if you reset your server credentials.

---

## 10. Authentication Modes

Hytale supports different authentication modes via the `--auth-mode` launch flag.

### Authenticated Mode (Default)

```bash
java -jar HytaleServer.jar --assets Assets.zip --auth-mode authenticated
```

- All connecting players must have a valid Hytale account.
- Usernames are verified against Hytale's servers.
- **This is the default and recommended mode for public servers.**

### Offline Mode

```bash
java -jar HytaleServer.jar --assets Assets.zip --auth-mode offline
```

- Players can join with **any username** without account verification.
- No authentication is performed.
- Player identity cannot be trusted (anyone can impersonate anyone).

> **Warning:** Only use offline mode for private/LAN servers where you trust everyone on the network. **Never use offline mode on a public server** — it exposes you to impersonation, griefing, and abuse with zero accountability.

---

## 11. Server Configuration

After the first launch, the server generates configuration files in `/opt/hytale/server/`.

### config.json (Main Server Config)

Located at `/opt/hytale/server/config.json`. Key settings:

```jsonc
{
  "server_name": "My Hytale Server",
  "max_players": 20,
  "view_distance": 12,
  "pvp": true,
  "whitelist_enabled": false
}
```

### permissions.json

Controls roles and permissions for players and operators.

### whitelist.json

Add player usernames to restrict server access:

```json
[
  "PlayerName1",
  "PlayerName2"
]
```

### World Configuration

Each world has its own `config.json` inside `universe/worlds/<world_name>/`:

```jsonc
{
  "Version": 1,
  "UUID": "...",
  "Seed": 12345,
  "WorldGen": "default",
  "PvP": true
}
```

> **Note:** Config files are read on startup. If you edit them while the server is running, your changes may be overwritten. Always stop the server before editing configs.

---

## 12. Firewall & Port Forwarding

### Hytale Networking Basics

- **Protocol:** QUIC over **UDP** (not TCP!)
- **Default port:** **5520**
- **Bind address:** `0.0.0.0:5520` (all interfaces)

### On Your Scala VPS (Already Handled by the Script)

```bash
# Verify firewall rules
ufw status

# Should show:
# 5520/udp    ALLOW    Anywhere
# 22/tcp      ALLOW    Anywhere
```

### Custom Port

If you want to use a different port, launch with:

```bash
java -Xms4G -Xmx4G -jar HytaleServer.jar --assets Assets.zip --bind 0.0.0.0:YOUR_PORT
```

And update your firewall:

```bash
ufw allow YOUR_PORT/udp
```

### Connecting

Players connect using your VPS IP address. If using the default port:
```
YOUR_VPS_IP
```

If using a custom port:
```
YOUR_VPS_IP:YOUR_PORT
```

---

## 13. DNS & Domain Setup

Instead of giving players a raw IP address, you can set up a domain name for easier connections.

### Point a Domain to Your VPS

1. Go to your domain registrar or DNS provider (e.g., Cloudflare, Namecheap, Google Domains)
2. Create an **A record**:
   - **Name:** `play` (or whatever subdomain you want, e.g., `play.yourdomain.com`)
   - **Type:** A
   - **Value:** Your VPS IP address
   - **TTL:** Auto (or 300)
3. Save and wait for DNS propagation (usually 5–15 minutes, can take up to 24 hours)

### Connecting via Domain

Once propagated, players can connect with:

```
play.yourdomain.com
```

Or with a custom port:

```
play.yourdomain.com:5520
```

> **Limitation:** Hytale does **not** currently support SRV records. If you're using a non-default port, players must include the port number in the connection address.

### Recommended DNS Provider

[Cloudflare](https://www.cloudflare.com/) offers free DNS hosting with fast propagation. Note that Cloudflare's proxy (orange cloud) does **not** work with UDP/QUIC game traffic — make sure the DNS record is set to **DNS only** (grey cloud).

---

## 14. Mods & Plugins

Hytale uses a **server-first modding approach** — players do not need to download or install mods themselves. The server streams all custom content (assets, scripts, textures) to connecting clients automatically.

### Types of Server Content

| Type | Format | Description |
|------|--------|-------------|
| **Plugins** | `.jar` | Java-based server logic (commands, events, custom mechanics) |
| **Content Packs** | `.zip` | JSON/asset-based content (blocks, items, models, textures) |

### Installing Mods

1. Stop the server: `systemctl stop hytale-server`
2. Place `.jar` or `.zip` files into the `mods/` directory:
   ```bash
   cp my-mod.jar /opt/hytale/server/mods/
   chown hytale:hytale /opt/hytale/server/mods/my-mod.jar
   ```
3. Start the server: `systemctl start hytale-server`

### Early Access Note

During early access, you may need the `--accept-early-plugins` flag to load third-party plugins:

```bash
java -Xms4G -Xmx4G -jar HytaleServer.jar --assets Assets.zip --accept-early-plugins
```

Update the `ExecStart` line in `/etc/systemd/system/hytale-server.service` if needed, then:

```bash
systemctl daemon-reload
systemctl restart hytale-server
```

### Where to Find Mods

[CurseForge](https://www.curseforge.com/hytale) is the official modding platform for Hytale, announced in partnership with Hypixel Studios.

> **Caution:** Only install mods from trusted sources. Malicious plugins have full access to your server process. Review mod permissions and source code when possible.

---

## 15. Managing Your Server

### Service Commands

```bash
# Start the server
systemctl start hytale-server

# Stop the server
systemctl stop hytale-server

# Restart the server
systemctl restart hytale-server

# Check server status
systemctl status hytale-server

# View live logs
journalctl -u hytale-server -f

# View recent logs
journalctl -u hytale-server --since "1 hour ago"
```

### Server Console Commands

The server runs under systemd, so use `journalctl` to view output. For interactive commands, stop the service and run the server directly (see [Section 9](#9-authenticating-your-server)).

Common server commands:

| Command | Description |
|---------|-------------|
| `/auth login device` | Authenticate the server |
| `/auth persistence Encrypted` | Save auth credentials encrypted |
| `/stop` | Gracefully stop the server |
| `/whitelist add <player>` | Add a player to the whitelist |
| `/whitelist remove <player>` | Remove a player from the whitelist |
| `/ban <player>` | Ban a player |
| `/pardon <player>` | Unban a player |
| `/op <player>` | Grant operator permissions |
| `/deop <player>` | Revoke operator permissions |

---

## 16. Backups

### Automated Backups (Configured by the One-Shot Script)

The install script sets up a cron job that runs every 30 minutes:

```bash
# View the backup cron job
crontab -u hytale -l
```

Backups are stored in `/opt/hytale/backups/` with timestamps. Old backups older than 24 hours are automatically deleted.

### Manual Backup

```bash
# Stop the server first for a clean backup
systemctl stop hytale-server

# Create a backup
tar -czf /opt/hytale/backups/hytale-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
  -C /opt/hytale/server universe/ config.json permissions.json whitelist.json bans.json

# Restart the server
systemctl start hytale-server
```

### Built-in Backup Flag

You can also use Hytale's built-in backup mechanism by adding flags to the launch command:

```bash
java -Xms4G -Xmx4G -jar HytaleServer.jar --assets Assets.zip \
  --backup --backup-frequency 30 --backup-dir /opt/hytale/backups
```

### Restore from Backup

```bash
systemctl stop hytale-server
cd /opt/hytale/server
tar -xzf /opt/hytale/backups/hytale-backup-TIMESTAMP.tar.gz
systemctl start hytale-server
```

---

## 17. Performance Tuning

### Memory Allocation

Set `-Xms` and `-Xmx` to ~75% of your VPS total RAM. Leave at least 1–2 GB for the OS.

| VPS RAM | Recommended `-Xmx` |
|---------|---------------------|
| 4 GB | `-Xmx3G` |
| 8 GB | `-Xmx6G` |
| 16 GB | `-Xmx12G` |

Update the value in `/etc/systemd/system/hytale-server.service`, then:

```bash
systemctl daemon-reload
systemctl restart hytale-server
```

> **Avoid swap:** Swap memory is orders of magnitude slower than RAM and will cause severe lag spikes. If your server needs swap, you need a bigger VPS plan.

### View Distance

View distance is the **single biggest performance lever**. Doubling view distance quadruples the loaded world area.

| Setting | Chunks | Blocks | Use Case |
|---------|--------|--------|----------|
| 8 | 8 | 256 | Tight, large player counts |
| 12 | 12 | 384 | Recommended for public servers |
| 16 | 16 | 512 | Small groups, more RAM |
| 24+ | 24+ | 768+ | Private, high-spec only |

Start at **12** and adjust based on your player count and RAM usage.

### AOT Cache (Faster Startup)

Java's Ahead-of-Time cache reduces startup time on repeat launches:

```bash
java -XX:AOTCache=HytaleServer.aot -Xms4G -Xmx4G -jar HytaleServer.jar --assets Assets.zip
```

### World Pre-Generation

On-demand chunk generation when players explore new areas causes lag. Pre-generating chunks around spawn reduces this:

- **Chunker** (available on [CurseForge](https://www.curseforge.com/hytale)) can pre-generate regions
- Consider pre-generating at least the spawn area before opening your server to players
- World config supports `PregenerateRegion` and `KeepLoadedRegion` options

---

## 18. Updating Your Server

### Using the Hytale Downloader CLI

```bash
systemctl stop hytale-server
su - hytale
cd /opt/hytale/server

# Check for updates
./hytale-downloader-linux-amd64 -check-update

# Download the update
./hytale-downloader-linux-amd64

exit  # back to root
systemctl start hytale-server
```

### Auto-Update Configuration

Hytale supports automatic updates via the `UpdateConfig` section in the server config. Admin commands:

| Command | Description |
|---------|-------------|
| `/update check` | Check for available updates |
| `/update download` | Download the latest update |
| `/update apply` | Apply the downloaded update |

> **Tip:** Always create a backup before applying updates. The one-shot script's automated backups help ensure you can roll back if an update causes issues.

### Pre-Release Builds

To switch to the pre-release branch (at your own risk):

```bash
./hytale-downloader-linux-amd64 -patchline pre-release
```

---

## 19. Troubleshooting

### Server won't start

```bash
# Check logs for errors
journalctl -u hytale-server -n 50 --no-pager

# Verify Java version
java --version  # Must be 25+

# Verify files exist
ls -la /opt/hytale/server/HytaleServer.jar
ls -la /opt/hytale/server/Assets.zip
```

### Players can't connect

1. **Verify the server is running:** `systemctl status hytale-server`
2. **Check the firewall:** `ufw status` — port 5520/udp must be ALLOW
3. **Confirm it's UDP, not TCP** — Hytale uses QUIC over UDP
4. **Check authentication:** server must be authenticated (`/auth login device`)
5. **Version mismatch:** ensure the server version matches the client version players are running
6. **Test the port externally:** Have a player try connecting, or use an online UDP port checker

### Authentication errors

- **"Invalid Token":** Your auth token may have expired. Run `/auth login device` again.
- **Time sync issues:** Ensure your server's clock is accurate: `timedatectl status`. Fix with: `sudo timedatectl set-ntp true`
- Check that you ran `/auth persistence Encrypted` to save credentials

### High RAM usage

- Lower `view_distance` in `config.json` (biggest impact)
- Reduce `max_players`
- Check for mods consuming excessive resources
- Check for duplicate mod files (old versions not removed during updates)
- Consider upgrading your Scala VPS plan

### Server crashes on startup

- Ensure you have enough free disk space: `df -h`
- Check for corrupted world data in `universe/worlds/`
- Try deleting `.cache/` and restarting (it will regenerate)
- Review crash logs in `logs/`

### Log Rotation

Hytale server logs can grow large over time. Set up logrotate to manage them:

```bash
cat > /etc/logrotate.d/hytale << 'EOF'
/opt/hytale/server/logs/*.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 0644 hytale hytale
}
EOF
```

---

## Quick Reference Card

| What | Value |
|------|-------|
| **Install directory** | `/opt/hytale/server` |
| **Backup directory** | `/opt/hytale/backups` |
| **Service name** | `hytale-server` |
| **Config file** | `/opt/hytale/server/config.json` |
| **Default port** | `5520/udp` |
| **Protocol** | QUIC over UDP |
| **Java version** | 25 (Temurin) |
| **Start** | `systemctl start hytale-server` |
| **Stop** | `systemctl stop hytale-server` |
| **Logs** | `journalctl -u hytale-server -f` |
| **Install details** | `/opt/hytale/credentials.txt` |

---

## Sources & References

- [Hytale Server Manual — Hypixel Studios](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)
- [Hytale EULA](https://hytale.com/eula) / [Server Operator Policies](https://hytale.com/server-policies)
- [OneShot Matrix — Automated Deployment Tool](https://github.com/loponai/oneshotmatrix)
- [Scala Hosting Self-Managed Linux VPS](https://www.scalahosting.com/linux-vps-hosting.html)
- [Hytale Server Setup Guide — Evolution Host](https://evolution-host.com/blog/how-to-set-up-a-hytale-server.php)
- [How to Make a Hytale Server — LOW.MS](https://low.ms/knowledgebase/how-to-create-a-hytale-server)
- [Hytale Server Requirements — Host Havoc](https://hosthavoc.com/blog/hytale-server-requirements)
- [Hytale Server Requirements — Hostinger](https://www.hostinger.com/tutorials/hytale-server-requirements)
- [Hytale EULA Guide — hytale.game](https://hytale.game/en/hytale-eula-guide-rules-for-your-server/)
- [Hytale Auto-Update Guide — HytaleLobby](https://www.hytalelobby.com/blog/how-to-update-a-hytale-server-the-2026-manual-auto-update-guide)
