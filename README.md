# 📦 Clawbox

> **Hermes Agent + 9Router + OpenClaw** — Free AI coding stack via Docker Compose

Clawbox combines three powerful open-source tools running as separate service stacks:

| Stack         | Services                           | Folder       | Ports                             |
| ------------- | ---------------------------------- | ------------ | --------------------------------- |
| **providers** | 9router + Headroom + DinD          | `providers/` | `20128`                           |
| **hermes**    | Hermes Agent (gateway + dashboard) | `hermes/`    | Dashboard `4999`                  |
| **openclaw**  | OpenClaw (gateway + proxy + CLI)   | `openclaw/`  | (proxy) `8080` / (direto) `18789` |

---

## 🚀 Quick Start

```bash
# 1. Clone or enter the directory
cd clawbox

# 2. Configure environment (opcional — tudo tem default)
make envs

# 3. Start providers (9router + headroom + dind)
make providers

# 4. Start Hermes (depends on 9router + dind)
make hermes

# 5. Start OpenClaw (depends on 9router)
make openclaw

# 6. Configure 9router provider no OpenClaw (extrai a chave automagicamente)
make openclaw-setup

# 7. Pegue a senha do proxy e o gateway token
make openclaw-auth    # mostra credenciais basic auth
make openclaw-token   # mostra o gateway token

# 8. Abra o Clawbox via proxy (recomendado):
open http://localhost:8080

# 7. Follow logs
make logs
```

---

## 📁 Project Structure

```
clawbox/
├── .env.example            # Shared vars (opcional)
├── Makefile                # Root orchestrator
│
├── providers/              # Core infrastructure
│   ├── .env / .env.example
│   ├── docker-compose.yml  # 9router + headroom + dind
│   └── Makefile
│
├── hermes/                 # Hermes Agent
│   ├── .env / .env.example
│   ├── docker-compose.yml  # hermes (gateway + dashboard)
│   └── Makefile
│
├── openclaw/               # OpenClaw
│   ├── .env / .env.example
│   ├── docker-compose.yml  # openclaw + openclaw-cli + nginx proxy
│   ├── Makefile
│   ├── nginx/
│   │   ├── nginx.conf       # proxy config (basic auth)
│   │   └── entrypoint.sh    # gera .htpasswd de env vars
│   └── scripts/openclaw-setup.sh
│
└── openclaw-workspace/     # Shared workspace (bind mount)
```

Each folder is self-contained — it has its own `docker-compose.yml`, `Makefile`,
and `.env` (runtime + compose variable substitution).

---

## 🔧 Architecture

```
  Your AI Tools (Cursor, Claude Code, Cline, Copilot…)
          │
          ▼
  ┌───────────────┐
  │   9router     │  ← OpenAI-compatible API at :20128
  │  (port 20128) │     Auto-fallback across 40+ providers
  │               │     RTK token saver (-20~40% tokens)
  └───┬───────┬───┘
      │       │ internal network (clawbox-net)
      ▼       ▼
  ┌──────────┐  ┌──────────────┐
  │ Hermes   │  │ OpenClaw     │
  │ Agent    │  │ (Control UI  │
  │(dashboard│  │  :18789      │
  │ :4999)   │  │  local)      │
  └──────────┘  └──────────────┘
```

Services communicate over a shared Docker bridge network (`clawbox-net`),
defined in `providers/docker-compose.yml` and declared as `external: true`
in the other stacks.

---

## 🌐 Connecting Your Tools to 9Router

Point any OpenAI-compatible tool to:

```
Base URL:  http://localhost:20128/v1
API Key:   sk-free-via-9router   (any string works)
```

### Claude Code

```bash
claude config set --global api_base_url http://localhost:20128/v1
claude config set --global api_key sk-free-via-9router
```

### Cursor

In Cursor settings → Models → OpenAI API:

- **Base URL:** `http://localhost:20128/v1`
- **API Key:** `sk-free-via-9router`

### Cline (VS Code Extension)

In Cline settings:

- **API Provider:** OpenAI Compatible
- **Base URL:** `http://localhost:20128/v1`
- **API Key:** `sk-free-via-9router`

### OpenClaw (configurado via setup)

OpenClaw usa o 9router como provider customizado (`9router/free-all`). Execute `make openclaw-setup` após subir o gateway para extrair a chave da API e registrar o provider automaticamente.

**Dois acessos disponíveis:**

| Via                     | URL                      | Segurança                     |
| ----------------------- | ------------------------ | ----------------------------- |
| **Proxy (recomendado)** | `http://localhost:8080`  | Basic auth + proxy reverso    |
| Gateway (direto)        | `http://localhost:18789` | Apenas token (sem basic auth) |

O Control UI pede um **Gateway Token** — veja o token gerado com:

```bash
make openclaw-token
# ou
docker exec clawbox-openclaw python3 -c "import json;print(json.load(open('/home/node/.openclaw/openclaw.json'))['gateway']['auth']['token'])"
```

**Credenciais do proxy:**

```bash
make openclaw-auth
```

### Hermes Agent (already configured)

Hermes is pre-configured to use `http://9router:20128/v1` inside Docker.

---

## ⚙️ Configuration

Each stack has its own `.env` file. Examples are provided as `.env.example`:

```bash
# Create .env from examples (already done if you ran make envs)
cp providers/.env.example providers/.env
cp hermes/.env.example hermes/.env
cp openclaw/.env.example openclaw/.env
```

Or use the shortcut:

```bash
make envs
```

All variables in the compose files have sensible defaults — no `.env` is
strictly required to start the stack. Override only what you need.

### providers/.env

| Variable       | Default | Description               |
| -------------- | ------- | ------------------------- |
| `ROUTER_PORT`  | `20128` | Host port for 9router API |
| `ROUTER_DEBUG` | `false` | Enable debug logging      |

### hermes/.env

| Variable                    | Default      | Description                   |
| --------------------------- | ------------ | ----------------------------- |
| `HERMES_DASHBOARD_PORT`     | `4999`       | Host port for dashboard       |
| `HERMES_DASHBOARD_USERNAME` | `admin`      | Dashboard basic auth          |
| `HERMES_DASHBOARD_PASSWORD` | `admin`      | Dashboard basic auth          |
| `OPENAI_API_KEY`            | —            | 9router API key               |
| `HERMES_DEFAULT_MODEL`      | `model-free` | Default LLM model             |
| `TELEGRAM_BOT_TOKEN`        | —            | Optional Telegram integration |
| `DISCORD_BOT_TOKEN`         | —            | Optional Discord integration  |

### openclaw/.env

| Variable                 | Default         | Description                       |
| ------------------------ | --------------- | --------------------------------- |
| `OPENCLAW_PORT`          | `18789`         | Host port (gateway direto)        |
| `OPENCLAW_PROXY_PORT`    | `8080`          | Host port (nginx proxy)           |
| `OPENCLAW_AUTH_USERNAME` | `admin`         | Nginx basic auth username         |
| `OPENCLAW_AUTH_PASSWORD` | `clawbox-admin` | Nginx basic auth password         |
| `ROUTER_9_API_KEY`       | —               | 9router API key (auto-preenchido) |

---

## 📊 Useful Commands

```bash
# ── Up ──────────────────────────────────────────
make providers        # Core: 9router + headroom + dind
make hermes           # Hermes (gateway + dashboard)
make openclaw         # OpenClaw
make openclaw-setup   # Configure 9router provider (auto-extracts key)
make all              # Everything

# ── Down ────────────────────────────────────────
make down             # Remove all containers (volumes preserved)
make down-hermes      # Only Hermes
make down-openclaw    # Only OpenClaw

# ── Logs ────────────────────────────────────────
make logs             # All services
make logs svc=9router # Only 9router
make logs svc=hermes  # Only Hermes
make logs svc=openclaw# Only OpenClaw

# ── Maintenance ─────────────────────────────────
make ps               # List containers
make pull             # Pull updated images
make build            # Rebuild local images
make clean            # down + remove volumes (WARNING: deletes data)
make envs             # Create .env from .env.example in each folder

# ── OpenClaw ────────────────────────────────────
make openclaw-ui      # Open Control UI via proxy (port 8080)
make openclaw-token   # Show the gateway token
make openclaw-auth    # Show proxy credentials
make openclaw-onboard # Initial onboarding
make openclaw-setup   # (Re)configure 9router provider

# ── Individual stacks ───────────────────────────
make -C providers up  # Start only providers
make -C hermes down   # Stop only Hermes
make -C openclaw logs # Logs only OpenClaw

# ── Open dashboards ─────────────────────────────
open http://localhost:20128/dashboard   # 9Router
open http://localhost:4999              # Hermes
open http://localhost:8080              # OpenClaw (via proxy, recomendado)
open http://localhost:18789             # OpenClaw (gateway direto)
```

---

## 🧪 DinD Sandbox

Run a full Docker daemon **inside a container** — isolated from the host. Useful for testing builds, CI pipelines, or ephemeral workloads.

### Hermes + DinD (auto-configurado)

O Hermes Agent já está configurado para usar o DinD como sandbox padrão:

```
Hermes Agent → DOCKER_HOST=tcp://dind:2375 → DinD (container isolado)
```

Qualquer comando `docker` que o Hermes executar (build, run, pull, ps)
vai automaticamente parar dentro do sandbox — sem configuração extra.

```bash
# Testar a conexão do Hermes com o DinD
docker exec clawbox-hermes docker info
docker exec clawbox-hermes docker run --rm alpine echo "sandbox ativo"
```

### Connect from your machine

```bash
# Point Docker client to the DinD sandbox
export DOCKER_HOST=tcp://<SERVER_IP>:2375

# Now everything runs inside the sandbox
docker info
docker pull alpine
docker run --rm alpine echo "hello from sandbox"
```

### Example — Build and test inside sandbox

```bash
export DOCKER_HOST=tcp://192.168.1.100:2375

# Clone and build in isolation
docker build -t my-app https://github.com/user/repo.git
docker run -d -p 8080:80 my-app
docker ps
```

### Reset the sandbox

```bash
docker compose -p clawbox -f providers/docker-compose.yml down dind
docker volume rm clawbox-dind-data
make providers
```

### ⚠️ Security

- The DinD API on port `2375` has **no authentication** — anyone on the network can run containers.
- Restrict access via firewall: `sudo ufw allow from 192.168.1.0/24 to any port 2375`
- Or use SSH tunnel: `ssh -L 2375:localhost:2375 user@server`

---

## 🔒 Security Notes

- All dashboards and UIs bind to `127.0.0.1` (loopback only) — accessible only from the local machine.
- To access remotely, use an SSH tunnel: `ssh -L 4999:localhost:4999 user@server`
- The dashboard stores API keys; **set a strong `HERMES_DASHBOARD_PASSWORD` in `hermes/.env`**.

---

## 📚 References

- [Hermes Agent Docs](https://hermes-agent.nousresearch.com/docs/)
- [9Router GitHub](https://github.com/decolua/9router)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [NousResearch Discord](https://discord.gg/NousResearch)
