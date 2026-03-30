#!/bin/bash
# EC2 Ubuntu 24.04 bootstrap — run once as root after launching instance
# Usage: sudo bash setup.sh

set -euo pipefail

echo "==> Installing Docker + Compose..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "==> Installing Certbot (Let's Encrypt)..."
apt-get install -y certbot

echo ""
echo "==> Next steps:"
echo "  1. Point your domain A record to this server's public IP."
echo "  2. Run: certbot certonly --standalone -d YOUR_DOMAIN"
echo "  3. Copy /etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem → server/certs/fullchain.pem"
echo "  4. Copy /etc/letsencrypt/live/YOUR_DOMAIN/privkey.pem  → server/certs/privkey.pem"
echo "  5. Create server/.env with your keys (see .env.example)."
echo "  6. cd server && docker compose up -d"
echo ""
echo "==> Certbot auto-renewal:"
echo "  (crontab -l 2>/dev/null; echo '0 3 * * * certbot renew --quiet && docker compose -f /srv/server/docker-compose.yml restart nginx') | crontab -"
