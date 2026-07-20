#!/usr/bin/env bash
# ============================================================
# sync-provider.sh — Sincroniza .env-provider com a chave real do 9router
# ============================================================
#
# Extrai a chave da API do banco SQLite do 9router (ou cria uma
# nova se não existir) e atualiza .env-provider na raiz.
#
# Uso: bash scripts/sync-provider.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_PROVIDER="$REPO_ROOT/.env-provider"

log()   { printf "\033[36m[INFO]\033[0m %s\n" "$*"; }
warn()  { printf "\033[33m[AVISO]\033[0m %s\n" "$*"; }
error() { printf "\033[31m[ERRO]\033[0m %s\n" "$*"; }

cd "$REPO_ROOT"

# ── Pré-condição: 9router rodando ─────────────────
log "Verificando se o 9router está rodando..."
if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'clawbox-9router'; then
    warn "9router não está rodando — usando chave default"
    warn "Execute 'make providers' primeiro, depois reexecute este script"
    log "Chave default mantida em .env-provider: PROVIDER_API_KEY=sk-free-via-9router"
    exit 0
fi

# ── Lê ou cria chave no SQLite ────────────────────
log "Lendo chave da API do banco 9router..."
KEY=$(docker exec clawbox-9router node -e "
const s = require('better-sqlite3')('/app/data/db/data.sqlite');
const r = s.prepare('SELECT key FROM apiKeys WHERE isActive=1 LIMIT 1').get();
console.log(r ? r.key : '');
s.close();
" 2>/dev/null || true)

if [ -n "$KEY" ]; then
    log "Chave existente encontrada: $KEY"
else
    log "Nenhuma chave ativa — criando nova..."
    KEY="sk-clawbox-$(docker exec clawbox-9router node -e "console.log(require('crypto').randomUUID().replace(/-/g,'').slice(0,16))")"
    ID="sync-$(docker exec clawbox-9router node -e "console.log(require('crypto').randomUUID().replace(/-/g,'').slice(0,12))")"
    NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
    docker exec clawbox-9router node -e "
const s = require('better-sqlite3')('/app/data/db/data.sqlite');
s.prepare('INSERT INTO apiKeys (id,key,name,machineId,isActive,createdAt) VALUES (?,?,?,?,1,?)').run('$ID','$KEY','sync-provider','clawbox','$NOW');
s.close();
" 2>/dev/null
    log "Nova chave criada: $KEY"
fi

# ── Atualiza .env-provider ────────────────────────
log "Atualizando .env-provider..."
if grep -q '^PROVIDER_API_KEY=' "$ENV_PROVIDER" 2>/dev/null; then
    sed -i '' "s|^PROVIDER_API_KEY=.*|PROVIDER_API_KEY=$KEY|" "$ENV_PROVIDER"
else
    echo "PROVIDER_API_KEY=$KEY" >> "$ENV_PROVIDER"
fi

# Garante que PROVIDER_BASE_URL existe
if ! grep -q '^PROVIDER_BASE_URL=' "$ENV_PROVIDER" 2>/dev/null; then
    echo "PROVIDER_BASE_URL=http://9router:20128/v1" >> "$ENV_PROVIDER"
fi

log ".env-provider atualizado com chave real do 9router"

# ── Propaga para os .env dos stacks ───────────────
log "Propagando para .env dos stacks..."
for stack in hermes openclaw nanobot; do
    local_env="$stack/.env"
    [ ! -f "$local_env" ] && continue

    # Map provider vars to stack-specific names
    case "$stack" in
        hermes)
            sed -i '' "s|^OPENAI_API_KEY=.*|OPENAI_API_KEY=$KEY|" "$local_env" 2>/dev/null || true
            sed -i '' "s|^HERMES_API_KEY=.*|HERMES_API_KEY=$KEY|" "$local_env" 2>/dev/null || true
            ;;
        openclaw)
            sed -i '' "s|^ROUTER_9_API_KEY=.*|ROUTER_9_API_KEY=$KEY|" "$local_env" 2>/dev/null || true
            ;;
        nanobot)
            sed -i '' "s|^OPENAI_API_KEY=.*|OPENAI_API_KEY=$KEY|" "$local_env" 2>/dev/null || true
            ;;
    esac
    log "  $stack/.env atualizado"
done

echo ""
log "✅ Provider sincronizado! Chave real propagada para todos os stacks."
