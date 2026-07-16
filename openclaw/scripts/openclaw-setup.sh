#!/usr/bin/env bash
set -euo pipefail

CLAWBOX_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== Verificando chave da API do 9router ==="

# Lê ou cria chave usando node/better-sqlite3 dentro do container (WAL-safe)
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
    NOW="2026-07-16T01:00:00.000Z"
    docker exec clawbox-9router node -e "
const s = require('better-sqlite3')('/app/data/db/data.sqlite');
s.prepare('INSERT INTO apiKeys (id,key,name,machineId,isActive,createdAt) VALUES (?,?,?,?,1,?)').run('$ID','$KEY','clawbox-setup','clawbox','$NOW');
s.close();
"
    echo "Chave criada: $KEY"
fi

echo ""
echo "=== Atualizando .env ==="
sed -i '' "s/^OPENAI_API_KEY=.*/OPENAI_API_KEY=$KEY/" "$CLAWBOX_DIR/.env"

echo ""
echo "=== Configurando provider 9router no OpenClaw ==="

# Lê o config atual do volume Docker, faz merge, e escreve de volta
# (evita config set --strict-json que corrompe gateway.*)
python3 -c "
import json, subprocess, sys

KEY_VAL = '$KEY'
cfg = {}

# Lê config atual do volume via container temporário
r = subprocess.run(
    ['docker', 'run', '--rm', '-v', 'clawbox-openclaw-state:/data',
     'alpine:3.19', 'sh', '-c', 'cat /data/openclaw.json 2>/dev/null || true'],
    capture_output=True, text=True
)
if r.returncode == 0 and r.stdout.strip():
    cfg = json.loads(r.stdout)
    print('Config existente lida com sucesso')
else:
    print('Nenhuma config existente — criando do zero')
    cfg = {
        'meta': {
            'lastTouchedVersion': '2026.7.1',
            'lastTouchedAt': '2026-07-16T00:00:00.000Z'
        }
    }

# Garante gateway
cfg.setdefault('gateway', {})
cfg['gateway'].setdefault('mode', 'local')
cfg['gateway'].setdefault('bind', 'lan')
cfg['gateway'].setdefault('port', 18789)
cfg['gateway'].setdefault('auth', {'mode': 'token', 'token': 'set-me-in-openclaw-env'})

# Configura models
cfg.setdefault('models', {})
cfg['models']['mode'] = 'merge'
cfg['models']['providers'] = {
    '9router': {
        'baseUrl': 'http://9router:20128/v1',
        'apiKey': KEY_VAL,
        'api': 'openai-completions',
        'models': [
            {'id': 'free-all', 'name': 'free-all', 'contextWindow': 128000, 'maxTokens': 16384, 'input': ['text']},
            {'id': 'kc/kilo-auto/free', 'name': 'kc/kilo-auto/free', 'contextWindow': 128000, 'maxTokens': 16384, 'input': ['text']}
        ]
    }
}

# Configura agent
cfg.setdefault('agents', {'defaults': {}})
cfg['agents']['defaults']['model'] = {'primary': '9router/free-all'}

# Escreve de volta via container temporário
encoded = json.dumps(cfg, indent=2, ensure_ascii=False)
p = subprocess.run(
    ['docker', 'run', '--rm', '-i', '--entrypoint', 'sh', '-v', 'clawbox-openclaw-state:/data',
     'alpine:3.19', '-c', 'cat > /data/openclaw.json'],
    input=encoded, capture_output=True, text=True
)
if p.returncode != 0:
    print('ERRO: nao foi possivel escrever config:', p.stderr)
    sys.exit(1)

print('Configuracao escrita com sucesso')
"

echo ""
echo "=== Reiniciando gateway OpenClaw ==="
docker compose -f "$CLAWBOX_DIR/docker-compose.yml" restart openclaw 2>/dev/null

echo ""
echo "✅ OpenClaw configurado com 9router/free-all"
