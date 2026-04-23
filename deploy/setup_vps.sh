#!/bin/bash
# Emlakdefter VPS Setup Script
# Run this ONCE on a fresh VPS to install all dependencies
# Usage: curl -fsSL https://raw.githubusercontent.com/kocakburhan/emlakdefter/master/deploy/setup_vps.sh | bash

set -e

echo "=== Emlakdefter VPS Setup ==="
echo "Running on: $(hostname)"
echo "Date: $(date)"

# ── System Update ──────────────────────────────────────────────────────────
echo "[1/8] Updating system..."
apt-get update && apt-get upgrade -y

# ── Docker Installation ──────────────────────────────────────────────────────
echo "[2/8] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    echo "Docker installed: $(docker --version)"
else
    echo "Docker already installed"
fi

# ── Docker Compose ──────────────────────────────────────────────────────────
echo "[3/8] Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose installed: $(docker-compose --version)"
else
    echo "Docker Compose already installed"
fi

# ── Firewall (UFW) ──────────────────────────────────────────────────────────
echo "[4/8] Configuring firewall..."
apt-get install -y ufw
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw --force enable

# ── Fail2Ban (SSH brute-force protection) ──────────────────────────────────
echo "[5/8] Installing Fail2Ban..."
apt-get install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# ── Timezone ────────────────────────────────────────────────────────────────
echo "[6/8] Setting timezone..."
timedatectl set-timezone Europe/Istanbul

# ── Create deployment directory ─────────────────────────────────────────────
echo "[7/8] Creating deployment directory..."
mkdir -p /opt/emlakdefter
cd /opt/emlakdefter

# ── Git clone (if not already present) ─────────────────────────────────────
if [ ! -d "/opt/emlakdefter/.git" ]; then
    echo "[8/8] Cloning repository..."
    # Replace with your actual repo URL
    git clone https://github.com/kocakburhan/emlakdefter.git .
else
    echo "[8/8] Repository already present, pulling latest..."
    cd /opt/emlakdefter
    git pull origin master
fi

echo ""
echo "=== Setup Complete ==="
echo "Next steps:"
echo "  1. Edit /opt/emlakdefter/backend/.env with real credentials"
echo "  2. Run: cd /opt/emlakdefter && docker-compose -f deploy/docker-compose.prod.yml up -d"
echo "  3. Check logs: docker-compose -f deploy/docker-compose.prod.yml logs -f"
