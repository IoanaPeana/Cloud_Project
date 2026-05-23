#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "[1/4] Starting all containers..."
sudo docker compose up -d --build

echo "[2/4] Waiting for Vault to be ready..."
for i in $(seq 1 30); do
  if sudo docker exec -e VAULT_ADDR=http://127.0.0.1:8200 vault vault status > /dev/null 2>&1; then
    echo "      Vault is up!"
    break
  fi
  echo "      Attempt $i/30..."
  sleep 3
done

echo "[3/4] Seeding secret into Vault..."
sudo docker exec \
  -e VAULT_ADDR=http://127.0.0.1:8200 \
  -e VAULT_TOKEN=devroottoken \
  vault vault secrets enable -path=secret kv-v2 2>/dev/null || true

API_KEY="prod-$(openssl rand -hex 20)"
sudo docker exec \
  -e VAULT_ADDR=http://127.0.0.1:8200 \
  -e VAULT_TOKEN=devroottoken \
  vault vault kv put secret/myapp api_key="${API_KEY}"

echo "[4/4] Restarting app to load secret..."
sudo docker restart app
sleep 5

echo ""
echo "=================================="
echo "  DEPLOYMENT COMPLETE"
echo "=================================="
echo "  App:        http://localhost"
echo "  Grafana:    http://localhost:3000  (admin / admin)"
echo "  Prometheus: http://localhost:9090"
echo "  API Key:    ${API_KEY}"
echo "=================================="
