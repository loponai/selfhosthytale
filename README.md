# selfhosthytale

**Deploy a self-hosted Hytale dedicated server in one command.** Automated setup with Java 25, systemd service, firewall, backups, and security hardening.

```bash
curl -fsSL https://raw.githubusercontent.com/loponai/selfhosthytale/main/install.sh | sudo bash
```

---

## Quick Start (Scala Hosting)

We recommend [Scala Hosting](http://scala.tomspark.tech/) because their self-managed VPS gives you **full root access** out of the box — which is required for Java, firewall, and systemd service configuration. KVM virtualization means dedicated resources with no overselling.

### Step 1: Get a VPS

1. Go to [Scala Hosting Self-Managed VPS](http://scala.tomspark.tech/) — make sure you're on the **Self-Managed** (unmanaged) plans, not the Managed ones
2. Pick **Build #3** (4 cores, 8GB RAM, 240GB NVMe) — ~$52–67/mo, recommended for 10–30 players
3. Under **OS**, select **Ubuntu 24.04 LTS** — this gives you a clean server ready for Hytale
4. Choose the data center location **closest to your players** for lowest latency
5. Complete checkout and wait for your welcome email with your server IP and root password

#### Hytale Server System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **RAM** | 4 GB | 8 GB+ |
| **CPU** | 2 cores (x64 or arm64) | 4 cores, 3.5 GHz+ |
| **Storage** | 20 GB SSD | 50 GB+ NVMe |
| **Java** | Java 25 (Temurin/Adoptium) | Java 25 |
| **OS** | Ubuntu 22.04+ / Debian 12+ | Ubuntu 24.04 LTS |
| **Network** | UDP port 5520 open | Unmetered bandwidth |

### Step 2: Read the EULA

Before hosting a Hytale server, you **must** review and accept:

- [Hytale End-User License Agreement (EULA)](https://hytale.com/eula)
- [Server Operator Policies](https://hytale.com/server-policies)

Key points:
- Operating a server constitutes acceptance of these terms.
- **Prohibited content:** sexual content, NFTs, crypto schemes, real-money gambling, pay-to-win mechanics.
- Server operators are responsible for all hosting costs, moderation, user content, and compliance with local laws.
- Hytale currently takes **0% commission** on server monetization for the first two years.
- There is a limit of **100 servers per Hytale game license**. Server providers hosting for others may need to apply for special accounts.

> Read the full policies before investing time in your server setup. Violations can result in your server being delisted or your account being banned.

### Step 3: SSH in

SSH is how you remotely control your server from a terminal. You type commands on your computer and they run on the VPS.

**On Mac/Linux:** Open Terminal (it's built in).

**On Windows:** Open **PowerShell** (search for it in the Start menu) or install [Windows Terminal](https://aka.ms/terminal) from the Microsoft Store.

Then connect to your server:

```bash
ssh root@YOUR_SERVER_IP
```

Replace `YOUR_SERVER_IP` with the IP from your Scala welcome email (e.g. `ssh root@142.248.180.64`).

> **Getting "Connection refused"?** Some Scala plans use port 6543 instead of the default. Try: `ssh root@YOUR_SERVER_IP -p 6543`. Check your welcome email for the correct SSH port.

- It will ask "Are you sure you want to continue connecting?" — type `yes` and press Enter
- Enter the **root password** from your Scala welcome email
  - **The screen will stay completely blank as you type or paste** — no dots, no stars, nothing. This is normal! Just paste your password and press Enter. It's there, you just can't see it.

Once you're in, you'll see a command prompt on your server.

### Step 4: Run the installer

```bash
curl -fsSL https://raw.githubusercontent.com/loponai/selfhosthytale/main/install.sh | sudo bash
```

You'll be asked for:
1. **Server memory** — how much RAM to allocate (default: ~75% of your VPS RAM)
2. **Server port** — UDP port to listen on (default: 5520)
3. **Enable backups** — automatic backups every 30 minutes (default: yes)

The installer handles everything: system updates, Java 25, Hytale Downloader, firewall rules, systemd service, and backup cron job.

### Step 5: Authenticate your server

After installation, your server needs to be linked to a Hytale account before players can connect.

1. Stop the service and run the server interactively:

```bash
systemctl stop hytale-server
su - hytale
cd /opt/hytale/server
java -Xms4G -Xmx4G -jar HytaleServer.jar --assets Assets.zip
```

2. In the server console, type:

```
/auth login device
```

3. The console will display a **URL** (`https://accounts.hytale.com/device`) and a **code** (e.g. `ABCD-1234`)
4. Open the URL in your browser, enter the code, and sign in with your Hytale account
5. After you see **"Authentication successful!"**, run:

```
/auth persistence Encrypted
```

This saves your credentials so you don't need to re-authenticate after every reboot.

6. Stop the interactive server (`Ctrl+C`) and start the service:

```bash
exit
systemctl start hytale-server
```

Players can now connect using your server's IP address on port 5520.

---

## What You Get

- **Java 25** (Eclipse Temurin/Adoptium) — installed and configured
- **Hytale Downloader CLI** — fetches the latest server files
- **HytaleServer.jar** — the dedicated server itself
- **Dedicated `hytale` system user** — no running as root
- **systemd service** — auto-starts on boot, restarts on crash, graceful shutdown
- **UFW firewall** — SSH and game port only, everything else blocked
- **Automated backups** — every 30 minutes with 24-hour retention
- **Security hardening** — NoNewPrivileges, PrivateTmp, ProtectSystem, ProtectHome
- **Install log** — everything logged to `/var/log/hytale-install.log`
- **Credentials file** — all install details saved to `/opt/hytale/credentials.txt`

## Why Scala Hosting?

| Feature | Why it matters |
|---------|---------------|
| **Full root access** | Required for Java, firewall, and systemd service configuration |
| **KVM virtualization** | Dedicated resources, no overselling — consistent performance |
| **NVMe storage** | Fast world loading and chunk I/O |
| **Unmetered bandwidth** | No surprise bills from player traffic |
| **Free snapshots** | Backup before changes, roll back if needed |
| **Scalable** | Add RAM ($3/GB) or CPU ($10/core) anytime |

| Plan | Price (Intro) | CPU | RAM | Storage | Best For |
|------|---------------|-----|-----|---------|----------|
| **Build #2** | ~$34–37/mo | 2 cores | 4 GB | 120 GB NVMe | 1–10 players (minimum viable) |
| **Build #3** | ~$52–67/mo | 4 cores | 8 GB | 240 GB NVMe | 10–30 players (recommended) |
| **Build #4** | ~$71–123/mo | 8 cores | 16 GB | 480 GB NVMe | 30–75+ players |

> **Pricing note:** Prices vary based on commitment length (1-month vs 1-year vs 3-year). **Renewal prices are higher than introductory rates.** Always check [the pricing page](http://scala.tomspark.tech/) for current rates.

**Recommended:** Start with [**Build #3**](http://scala.tomspark.tech/) if you expect more than a handful of players. Hytale uses view-distance-based chunk loading which scales RAM usage quickly. You can always upgrade later through Scala's panel.

---

## After Installation

### SSH Security Hardening

Your VPS is publicly accessible. After installation, harden SSH access to prevent brute-force attacks.

#### Create a non-root user

```bash
adduser gameadmin
usermod -aG sudo gameadmin
```

#### Set up SSH key authentication

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

#### Disable password authentication

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

#### Install fail2ban

fail2ban automatically blocks IPs after repeated failed login attempts:

```bash
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

To check banned IPs:

```bash
sudo fail2ban-client status sshd
```

> **Important:** After these steps, always use `ssh gameadmin@YOUR_VPS_IP` to connect, then `sudo` for root commands.

### Authentication Modes

Hytale supports different authentication modes via the `--auth-mode` launch flag.

**Authenticated Mode (Default):**
```bash
java -jar HytaleServer.jar --assets Assets.zip --auth-mode authenticated
```
All connecting players must have a valid Hytale account. Usernames are verified. **This is the default and recommended mode for public servers.**

**Offline Mode:**
```bash
java -jar HytaleServer.jar --assets Assets.zip --auth-mode offline
```
Players can join with any username without account verification. No authentication is performed.

> **Warning:** Only use offline mode for private/LAN servers where you trust everyone on the network. **Never use offline mode on a public server** — it exposes you to impersonation, griefing, and abuse with zero accountability.

### DNS & Domain Setup

Instead of giving players a raw IP address, set up a domain name for easier connections.

1. Go to your DNS provider (e.g. [Cloudflare](https://www.cloudflare.com/), free)
2. Create an **A record**:

| Type | Name | Content | Proxy status |
|------|------|---------|-------------|
| A | `play` (or `@`) | Your VPS IP | **DNS only** (grey cloud) |

> **The proxy must be off (grey cloud, "DNS only").** Cloudflare's proxy does **not** work with UDP/QUIC game traffic.

3. Wait for propagation (usually 5–15 minutes)

Players can then connect with `play.yourdomain.com` instead of an IP address.

> **Limitation:** Hytale does **not** support SRV records. If you're using a non-default port, players must include the port number: `play.yourdomain.com:5520`

### View credentials

```bash
cat /opt/hytale/credentials.txt
```

---

## Server Configuration

After the first launch, the server generates configuration files in `/opt/hytale/server/`.

### config.json (Main Server Config)

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

Each world has its own config inside `universe/worlds/<world_name>/`:

```jsonc
{
  "Version": 1,
  "UUID": "...",
  "Seed": 12345,
  "WorldGen": "default",
  "PvP": true
}
```

> Config files are read on startup. Always stop the server before editing configs — changes may be overwritten otherwise.

### Custom Port

Launch with a different port:

```bash
java -Xms4G -Xmx4G -jar HytaleServer.jar --assets Assets.zip --bind 0.0.0.0:YOUR_PORT
```

Update firewall: `ufw allow YOUR_PORT/udp`

---

## Mods & Plugins

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

During early access, you may need the `--accept-early-plugins` flag to load third-party plugins. Update the `ExecStart` line in `/etc/systemd/system/hytale-server.service`, then:

```bash
systemctl daemon-reload
systemctl restart hytale-server
```

### Where to Find Mods

[CurseForge](https://www.curseforge.com/hytale) is the official modding platform for Hytale.

> **Caution:** Only install mods from trusted sources. Malicious plugins have full access to your server process.

---

## Managing Your Server

### Everyday Commands

```bash
systemctl start hytale-server       # Start the server
systemctl stop hytale-server        # Stop the server
systemctl restart hytale-server     # Restart the server
systemctl status hytale-server      # Check server status
journalctl -u hytale-server -f      # View live logs
journalctl -u hytale-server --since "1 hour ago"  # Recent logs
```

### Server Console Commands

For interactive commands, stop the service and run the server directly (see [Step 5](#step-5-authenticate-your-server)).

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

### Backups

The installer sets up automatic backups every 30 minutes. Old backups are deleted after 24 hours.

```bash
# View the backup cron job
crontab -u hytale -l

# Manual backup
systemctl stop hytale-server
tar -czf /opt/hytale/backups/hytale-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
  -C /opt/hytale/server universe/ config.json permissions.json whitelist.json bans.json
systemctl start hytale-server

# Restore from backup
systemctl stop hytale-server
cd /opt/hytale/server
tar -xzf /opt/hytale/backups/hytale-backup-TIMESTAMP.tar.gz
systemctl start hytale-server
```

You can also use Hytale's built-in backup mechanism:

```bash
java -Xms4G -Xmx4G -jar HytaleServer.jar --assets Assets.zip \
  --backup --backup-frequency 30 --backup-dir /opt/hytale/backups
```

### Updating Your Server

```bash
systemctl stop hytale-server
su - hytale
cd /opt/hytale/server
./hytale-downloader-linux-amd64 -check-update
./hytale-downloader-linux-amd64
exit
systemctl start hytale-server
```

Or use in-game update commands:

| Command | Description |
|---------|-------------|
| `/update check` | Check for available updates |
| `/update download` | Download the latest update |
| `/update apply` | Apply the downloaded update |

> Always create a backup before applying updates.

---

## Performance Tuning

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

| Setting | Use Case |
|---------|----------|
| 8 | Tight, large player counts |
| 12 | Recommended for public servers |
| 16 | Small groups, more RAM |
| 24+ | Private, high-spec only |

Start at **12** and adjust based on your player count and RAM usage.

### AOT Cache (Faster Startup)

Java's Ahead-of-Time cache reduces startup time on repeat launches:

```bash
java -XX:AOTCache=HytaleServer.aot -Xms4G -Xmx4G -jar HytaleServer.jar --assets Assets.zip
```

### World Pre-Generation

On-demand chunk generation when players explore causes lag. Pre-generate chunks around spawn:

- **Chunker** (available on [CurseForge](https://www.curseforge.com/hytale)) can pre-generate regions
- Consider pre-generating at least the spawn area before opening your server to players

---

## Manual Setup (If You Prefer)

If you'd rather do it step by step instead of using the one-shot script:

### Update the system

```bash
apt update && apt upgrade -y
```

### Install Java 25 (Adoptium Temurin)

```bash
apt install -y wget apt-transport-https gpg lsb-release
mkdir -p /etc/apt/keyrings
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
    | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg
echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/adoptium.list
apt update
apt install -y temurin-25-jdk
java --version  # Should output: openjdk 25.x.x
```

### Create a dedicated user

```bash
useradd -r -m -d /opt/hytale -s /bin/bash hytale
```

### Download Hytale server files

```bash
su - hytale
mkdir -p /opt/hytale/server
cd /opt/hytale/server
wget https://downloader.hytale.com/hytale-downloader.zip
apt install -y unzip
unzip hytale-downloader.zip
chmod +x hytale-downloader-linux-amd64
./hytale-downloader-linux-amd64
```

### First launch (test run)

```bash
java -Xms4G -Xmx4G -jar HytaleServer.jar --assets Assets.zip
```

Stop with `Ctrl+C` after it finishes loading.

### Create a systemd service

Switch back to root (`exit`), then:

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

### Open the firewall

```bash
ufw allow 5520/udp comment "Hytale Server"
ufw allow 22/tcp comment "SSH"
ufw --force enable
```

---

## Troubleshooting

### Server won't start

```bash
journalctl -u hytale-server -n 50 --no-pager   # Check logs
java --version                                   # Must be 25+
ls -la /opt/hytale/server/HytaleServer.jar       # Verify files exist
ls -la /opt/hytale/server/Assets.zip
```

### Players can't connect

1. **Verify the server is running:** `systemctl status hytale-server`
2. **Check the firewall:** `ufw status` — port 5520/udp must be ALLOW
3. **Confirm it's UDP, not TCP** — Hytale uses QUIC over UDP
4. **Check authentication:** server must be authenticated (`/auth login device`)
5. **Version mismatch:** ensure the server version matches the client version
6. **Test the port externally:** have a player try connecting, or use an online UDP port checker

### Authentication errors

- **"Invalid Token":** Your auth token may have expired. Run `/auth login device` again.
- **Time sync issues:** Ensure your server's clock is accurate: `timedatectl status`. Fix with: `sudo timedatectl set-ntp true`
- Check that you ran `/auth persistence Encrypted` to save credentials

### High RAM usage

- Lower `view_distance` in `config.json` (biggest impact)
- Reduce `max_players`
- Check for mods consuming excessive resources
- Check for duplicate mod files (old versions not removed during updates)
- Consider [upgrading your Scala VPS plan](http://scala.tomspark.tech/)

### Server crashes on startup

- Ensure you have enough free disk space: `df -h`
- Check for corrupted world data in `universe/worlds/`
- Try deleting `.cache/` and restarting (it will regenerate)
- Review crash logs in `logs/`

### Log rotation

Hytale server logs can grow large over time. Set up logrotate:

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

## Reference

### Requirements

- **Ubuntu 22.04+** or **Debian 12+** on an unmanaged VPS with full root access
- **4 GB RAM** minimum, 8 GB+ recommended
- A [Hytale account](https://hytale.com) for server authentication
- UDP port 5520 open

### Key Files

| File | What it does |
|------|-------------|
| `/opt/hytale/server/config.json` | Main server config — name, max players, view distance |
| `/opt/hytale/server/permissions.json` | Player roles and permissions |
| `/opt/hytale/server/whitelist.json` | Whitelisted player usernames |
| `/opt/hytale/server/universe/` | World data |
| `/opt/hytale/server/mods/` | Server mods and plugins |
| `/opt/hytale/server/logs/` | Server logs |
| `/opt/hytale/backups/` | Automated backups |
| `/opt/hytale/credentials.txt` | Install details and saved commands |
| `/etc/systemd/system/hytale-server.service` | systemd service definition |

### Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 5520 | UDP | Hytale game traffic (QUIC) |
| 22 | TCP | SSH access |

### Quick Reference

| What | Value |
|------|-------|
| **Install directory** | `/opt/hytale/server` |
| **Backup directory** | `/opt/hytale/backups` |
| **Service name** | `hytale-server` |
| **Default port** | `5520/udp` |
| **Protocol** | QUIC over UDP |
| **Java version** | 25 (Temurin) |
| **Start** | `systemctl start hytale-server` |
| **Stop** | `systemctl stop hytale-server` |
| **Logs** | `journalctl -u hytale-server -f` |

### Sources

- [Hytale Server Manual — Hypixel Studios](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)
- [Hytale EULA](https://hytale.com/eula) / [Server Operator Policies](https://hytale.com/server-policies)
- [Scala Hosting Self-Managed Linux VPS](http://scala.tomspark.tech/)
