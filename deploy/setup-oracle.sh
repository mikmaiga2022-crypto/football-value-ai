#!/usr/bin/env bash
# Installation sur Oracle Cloud Always Free (Ubuntu 22.04)
set -euo pipefail

echo "=== Mise a jour systeme ==="
sudo apt-get update -y
sudo apt-get upgrade -y

echo "=== Installation Docker ==="
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"

echo "=== Pare-feu (ufw) ==="
sudo apt-get install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo "=== Clone du projet ==="
cd "$HOME"
if [ ! -d "football-value-ai" ]; then
  git clone https://github.com/mikmaiga2022-crypto/football-value-ai.git
fi
cd football-value-ai

echo "=== Preparation .env ==="
if [ ! -f deploy/.env ]; then
  cp deploy/.env.prod.example deploy/.env
  echo "Editez deploy/.env (DOMAIN, POSTGRES_PASSWORD, FVA_JWT_SECRET) puis relancez ce script avec: bash deploy/setup-oracle.sh --start"
fi

if [ "${1:-}" = "--start" ]; then
  echo "=== Demarrage des services ==="
  docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d --build
  echo "=== Etat ==="
  docker compose -f deploy/docker-compose.prod.yml ps
  echo "Test: curl -s https://\$DOMAIN/v1/health"
fi

echo "Termine. Reconnectez-vous pour appliquer le groupe docker, ou utilisez 'sudo' pour docker."
