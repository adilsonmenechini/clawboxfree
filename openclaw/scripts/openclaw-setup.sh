#!/usr/bin/env bash
# ============================================================
# openclaw-setup.sh — Sincroniza chave 9router com OpenClaw
#
# Escreve a chave da API do 9router no .env como ROUTER_9_API_KEY
# e configura o openclaw.json para referenciá-la via env var.
# O segredo nunca fica no openclaw.json — só no .env (gitignored).
# ============================================================
set -euo pipefail

CLAWBOX_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$CLAWBOX_DIR/.env"

echo "=== Verificando chave da API do 9router ==="

# Lê chave do banco 9router (WAL-safe via better-sqlite3)
KEY=$(docker exec clawbox-9router node -e "
const s = require('better-sqlite3')('/app/data/db/data.sqlite');
const r = s.prepare('SELECT key FROM apiKeys WHERE isActive=1 LIMIT 1').get();
console.log(r ? r.key : '');
s.close();
")

if [ -n "$KEY" ]; then
    echo "Usando chave existente: $KEY"
else
    echo "Criando nova chave..."
    KEY="sk-clawbox-$(docker exec clawbox-9router node -e "console.log(require('crypto').randomUUID().replace(/-/g,'').slice(0,16))")"
    ID="setup-$(docker exec clawbox-9router node -e "console.log(require('crypto').randomUUID().replace(/-/g,'').slice(0,12))")"
    NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
    docker exec clawbox-9router node -e "
const s = require('better-sqlite3')('/app/data/db/data.sqlite');
s.prepare('INSERT INTO apiKeys (id,key,name,machineId,isActive,createdAt) VALUES (?,?,?,?,1,?)').run('$ID','$KEY','clawbox-setup','clawbox','$NOW');
s.close();
"
    echo "Chave criada: $KEY"
fi

echo ""
echo "=== Escrevendo chave no .env ==="

# Atualiza ou adiciona ROUTER_9_API_KEY no .env
if grep -q '^ROUTER_9_API_KEY=' "$ENV_FILE" 2>/dev/null; then
    sed -i '' "s|^ROUTER_9_API_KEY=.*|ROUTER_9_API_KEY=$KEY|" "$ENV_FILE"
else
    echo "" >> "$ENV_FILE"
    echo "ROUTER_9_API_KEY=$KEY" >> "$ENV_FILE"
fi
echo "ROUTER_9_API_KEY atualizado no .env"

echo ""
echo "=== Sincronizando ref no OpenClaw (CLI) ==="

# Seta o config para referenciar a env var em vez de guardar o literal
docker compose -p clawbox run --rm openclaw-cli \
    config set models.providers.9router.apiKey \
    --ref-provider default --ref-source env --ref-id ROUTER_9_API_KEY 2>/dev/null || {
    echo "Aviso: config set falhou — tentando fallback Python..."
    # Fallback: escreve o ref direto no JSON via Python
    docker exec clawbox-openclaw python3 -c "
import json, os
config_path = os.environ.get('OPENCLAW_CONFIG_PATH',
    os.path.join(os.environ.get('OPENCLAW_STATE_DIR', '/home/node/.openclaw'), 'openclaw.json'))
try:
    with open(config_path) as f:
        cfg = json.load(f)
except FileNotFoundError:
    cfg = {}
cfg.setdefault('models', {})
cfg.setdefault('gateway', {})
cfg['gateway']['bind'] = 'lan'
cfg['models']['mode'] = 'merge'
cfg['models']['providers'] = cfg['models'].get('providers', {})
cfg['models']['providers']['9router'] = {
    'baseUrl': 'http://9router:20128/v1',
    'apiKey': {'source': 'env', 'provider': 'default', 'id': 'ROUTER_9_API_KEY'},
    'api': 'openai-completions',
    'models': [
        {'id': 'free-all', 'name': 'free-all', 'contextWindow': 128000, 'maxTokens': 16384, 'input': ['text']},
        {'id': 'mmf/mimo-auto', 'name': 'mmf/mimo-auto', 'contextWindow': 128000, 'maxTokens': 16384, 'input': ['text']}
    ]
}
with open(config_path, 'w') as f:
    json.dump(cfg, f, indent=2)
print('Ref escrito com sucesso via fallback')
"
}

echo ""
echo "=== Sincronizando gateway token ==="

# Extrai o token do config e salva no .env
TOKEN=$(docker exec clawbox-openclaw python3 -c "
import json
with open('/home/node/.openclaw/openclaw.json') as f:
    cfg = json.load(f)
print(cfg.get('gateway', {}).get('auth', {}).get('token', ''))
" 2>/dev/null || true)

if [ -n "$TOKEN" ] && [ "$TOKEN" != "clawbox-init-token" ]; then
    if grep -q '^OPENCLAW_GATEWAY_TOKEN=' "$ENV_FILE" 2>/dev/null; then
        sed -i '' "s|^OPENCLAW_GATEWAY_TOKEN=.*|OPENCLAW_GATEWAY_TOKEN=$TOKEN|" "$ENV_FILE"
    else
        echo "" >> "$ENV_FILE"
        echo "OPENCLAW_GATEWAY_TOKEN=$TOKEN" >> "$ENV_FILE"
    fi
    echo "Gateway token sincronizado no .env"
fi

echo ""
echo "=== Reiniciando gateway OpenClaw ==="
docker compose -p clawbox restart openclaw >/dev/null 2>&1

echo ""
echo "✅ OpenClaw configurado — chave 9router em .env (ROUTER_9_API_KEY), config com ref"
