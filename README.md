# Self-Host Hytale

One-command installer and complete guide for running a dedicated Hytale server on a Linux VPS.

## Quick Start

SSH into your fresh Ubuntu/Debian VPS as root and run:

```bash
curl -fsSL https://raw.githubusercontent.com/loponai/selfhosthytale/main/install.sh | sudo bash
```

The script handles everything: Java 25 installation, Hytale Downloader setup, systemd service, firewall rules, automated backups, and security hardening.

## What's Included

| File | Description |
|------|-------------|
| [**install.sh**](install.sh) | One-shot automated installer script |
| [**guide.md**](guide.md) | Full step-by-step guide with manual setup, configuration, troubleshooting, and more |

## Requirements

- **OS:** Ubuntu 22.04+ or Debian 12+ (fresh install recommended)
- **RAM:** 4 GB minimum, 8 GB+ recommended
- **CPU:** 2+ cores (x64 or arm64)
- **Storage:** 20 GB+ SSD
- **Network:** UDP port 5520 open
- **Account:** A [Hytale account](https://hytale.com) for server authentication

## What the Installer Does

1. Installs Java 25 (Eclipse Temurin/Adoptium)
2. Downloads the official Hytale Downloader
3. Downloads and sets up HytaleServer.jar
4. Creates a dedicated `hytale` system user
5. Configures a systemd service for auto-start on boot
6. Sets up UFW firewall rules (SSH + game port)
7. Creates automated daily backup cron job with 7-day retention
8. Applies systemd security hardening (sandboxing, private tmp, filesystem protection)
9. Logs everything to `/var/log/hytale-install.log`

## After Installation

1. **Authenticate your server** — visit https://accounts.hytale.com/device and enter the code shown in the server console
2. **Make it persist across restarts** — run `/auth persistence Encrypted` in the server console
3. **Connect** — open Hytale and join via your server's IP address on port 5520

## Full Guide

Read **[guide.md](guide.md)** for the complete walkthrough covering:

- Scala Hosting VPS plan recommendations and setup
- SSH security hardening (key auth, fail2ban)
- EULA and Server Operator Policy compliance
- Server configuration and performance tuning
- DNS and domain setup
- Mods and plugins
- Troubleshooting common issues

## Recommended VPS

This guide is written for [Scala Hosting Self-Managed VPS](https://www.scalahosting.com/linux-vps-hosting.html) plans, but the installer works on any Ubuntu/Debian VPS with root access.

| Plan | RAM | CPU | Best For |
|------|-----|-----|----------|
| Build #2 | 4 GB | 2 cores | 1–10 players |
| Build #3 | 8 GB | 4 cores | 10–30 players (recommended) |
| Build #4 | 16 GB | 8 cores | 30–75+ players |

## License

MIT
