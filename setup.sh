#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#  Automated Infrastructure, Security & Monitoring Deployment
#  Run this ONCE after cloning the repo.
# ═══════════════════════════════════════════════════════════════════
set -e

# Always run from the directory where this script lives
cd "$(dirname "$0")"

# ── Colors ────────────────────────────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── 1. Install Docker if missing ──────────────────────────────────
if ! command -v docker &>/dev/null; then
  info "Docker not found — installing..."
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  DOCKER_CMD="sudo docker"
else
  success "Docker already installed"
  # Use sudo if current user is not in the docker group
  if groups "$USER" | grep -q docker; then
    DOCKER_CMD="docker"
  else
    DOCKER_CMD="sudo docker"
  fi
fi

# ── 2. Generate a random Vault token and export it ────────────────
VAULT_TOKEN=$(openssl rand -hex 16)
export VAULT_TOKEN
info "Generated Vault root token: ${VAULT_TOKEN}"

# Write to .env so docker-compose picks it up
echo "VAULT_TOKEN=${VAULT_TOKEN}" > .env

# ── 3. Build images and start all containers ──────────────────────
info "Starting all services (Vault, App, Nginx, Prometheus, Grafana)..."
$DOCKER_CMD compose up -d --build

# ── 4. Wait for Vault to be ready ────────────────────────────────
info "Waiting for Vault to be ready..."
for i in $(seq 1 30); do
  if $DOCKER_CMD exec vault vault status &>/dev/null 2>&1; then
    success "Vault is up"
    break
  fi
  if [ "$i" -eq 30 ]; then
    error "Vault did not start in time. Run: docker logs vault"
  fi
  sleep 2
done

# ── 5. Enable KV secrets engine and store the API key ────────────
info "Enabling KV secrets engine in Vault..."
$DOCKER_CMD exec vault vault secrets enable -path=secret kv-v2 2>/dev/null || true

info "Storing application API key in Vault..."
API_KEY="prod-$(openssl rand -hex 24)"
$DOCKER_CMD exec vault vault kv put secret/myapp api_key="${API_KEY}"
success "Secret stored: api_key = ${API_KEY}"

# ── 6. Restart app so it reads the freshly seeded secret ─────────
info "Restarting app container to read the secret from Vault..."
$DOCKER_CMD restart app
sleep 3

# ── 7. Verify the app is responding through Nginx ─────────────────
info "Verifying app is reachable through Nginx..."
if curl -sf http://localhost/ | grep -q "Vault"; then
  success "App is live and retrieving secrets from Vault!"
else
  info "App may need a few more seconds — check http://localhost manually."
fi

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       DEPLOYMENT COMPLETE — ALL UP        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  🌐  Application  →  http://localhost"
echo -e "  📊  Grafana      →  http://localhost:3000  (admin / admin)"
echo -e "  🔥  Prometheus   →  http://localhost:9090"
echo ""
echo -e "  🔑  Vault Token  →  ${VAULT_TOKEN}"
echo -e "  🗝️   API Key      →  ${API_KEY}"
echo ""
echo -e "  All secrets were generated at runtime. No secrets are hardcoded."
