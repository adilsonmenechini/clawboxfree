#!/usr/bin/env bash
# ============================================================
# openclaw-setup.sh — Configura provider 9router no OpenClaw
#
# O configure.js da imagem coollabsio/openclaw já mapeia as
# env vars (OPENCLAW_GATEWAY_TOKEN, OPENCLAW_PRIMARY_MODEL,
# OPENCLAW_ALLOWED_ORIGINS, AUTH_PASSWORD etc.) para o
# openclaw.json automaticamente na inicialização.
#
# Este script apenas sincroniza a chave da API do 9router
# (extraída do banco SQLite) com o config do OpenClaw.
# ============================================================
set -euo pipefail

CLAWBOX_DIR="$(cd "$(dirname "$0")/.." && pwd)"

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
echo "=== Sincronizando chave no OpenClaw ==="

# Usa o CLI oficial para atualizar a chave no config
# (mais seguro que manipular o volume manualmente)
docker compose -p clawbox run --rm openclaw-cli \
    config set models.providers.9router.apiKey "$KEY" --strict-json 2>/dev/null || {
    echo "Aviso: config set falhou — tentando via volume..."
    # Fallback: se o config ainda não existe (onboarding não feito),
    # usa o Python no container
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
    'apiKey': '$KEY',
    'api': 'openai-completions',
    'models': [
        {'id': 'free-all', 'name': 'free-all', 'contextWindow': 128000, 'maxTokens': 16384, 'input': ['text']},
        {'id': 'mmf/mimo-auto', 'name': 'mmf/mimo-auto', 'contextWindow': 128000, 'maxTokens': 16384, 'input': ['text']}
    ]
}
with open(config_path, 'w') as f:
    json.dump(cfg, f, indent=2)
print('Configuracao escrita com sucesso')
"
}

echo ""
echo "=== Reiniciando gateway OpenClaw ==="
docker kill --signal=USR1 clawbox-openclaw 2>/dev/null || \
    docker restart clawbox-openclaw >/dev/null

echo ""
echo "✅ OpenClaw configurado com 9router/free-all"
