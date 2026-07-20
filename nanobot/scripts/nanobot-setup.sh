#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

COMPOSE_PREFIX="docker compose -p clawbox"
COMPOSE_NANOBOT="-f nanobot/docker-compose.yml"

log() { printf "\033[36m[INFO]\033[0m %s\n" "$*"; }
warn() { printf "\033[33m[AVISO]\033[0m %s\n" "$*"; }

cd "$REPO_ROOT"

# ── Lê do .env-provider central (com fallback) ────
ENV_PROVIDER="$REPO_ROOT/.env-provider"
if [ -f "$ENV_PROVIDER" ]; then
    PROVIDER_KEY=$(grep '^PROVIDER_API_KEY=' "$ENV_PROVIDER" | cut -d= -f2-)
    PROVIDER_URL=$(grep '^PROVIDER_BASE_URL=' "$ENV_PROVIDER" | cut -d= -f2-)
    PROVIDER_MODEL=$(grep '^PROVIDER_MODEL=' "$ENV_PROVIDER" | cut -d= -f2-)
fi
PROVIDER_KEY="${PROVIDER_KEY:-sk-free-via-9router}"
PROVIDER_URL="${PROVIDER_URL:-http://9router:20128/v1}"
PROVIDER_MODEL="${PROVIDER_MODEL:-gpt-4o-mini}"

log "Configurando provider: $(echo "$PROVIDER_URL" | sed 's|/v1$||') / $PROVIDER_MODEL"

$COMPOSE_PREFIX $COMPOSE_NANOBOT run --rm --entrypoint python3 nanobot-cli -c "
import json, os
p = '/home/nanobot/.nanobot/config.json'
if not os.path.exists(p):
    print('ERRO: config.json nao encontrado'); exit(1)
c = json.load(open(p))
c.setdefault('providers',{}).setdefault('openai',{})
c['providers']['openai']['apiKey'] = '${PROVIDER_KEY}'
c['providers']['openai']['apiBase'] = '${PROVIDER_URL}'
c.setdefault('agents',{}).setdefault('defaults',{})
c['agents']['defaults']['provider'] = 'openai'
c['agents']['defaults']['model'] = '${PROVIDER_MODEL}'
c['agents']['defaults']['temperature'] = 0.1
c.setdefault('channels',{}).setdefault('websocket',{})
c['channels']['websocket']['enabled'] = True
c['channels']['websocket']['port'] = 8765
c['channels']['websocket']['host'] = '0.0.0.0'
c['channels']['websocket']['tokenIssueSecret'] = 'clawbox-webui'
json.dump(c, open(p,'w'), indent=2)
print('OK - configurado via .env-provider')
" 2>&1

log "Provider configurado — chave: ${PROVIDER_KEY:0:12}..., modelo: $PROVIDER_MODEL"
