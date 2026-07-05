# 📦 Clawbox

> **Hermes Agent + 9Router** — Free AI coding stack via Docker Compose

Clawbox combines two powerful open-source tools:

| Service | Description | Port |
|---------|-------------|------|
| **[9router](https://github.com/decolua/9router)** | OpenAI-compatible proxy with 40+ free providers, auto-fallback, RTK token saver | `20128` |
| **[Hermes Agent](https://github.com/NousResearch/hermes-agent)** | Self-improving AI agent by NousResearch, pointed at 9router | Dashboard `4999` |

---

## 🚀 Quick Start

```bash
# 1. Clone or enter the directory
cd clawbox

# 2. Configure your environment
cp .env.example .env

# 3. Start everything
docker compose up -d

# 4. Follow logs
docker compose logs -f
```

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
  └───────┬───────┘
          │ internal network
          ▼
  ┌───────────────┐
  │ Hermes Agent  │  ← Self-improving AI agent
  │  (dashboard   │     Telegram / Discord / CLI gateway
  │  :4999 local) │     Skills, memory, scheduled automations
  └───────────────┘
```

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

### Hermes Agent (already configured)
Hermes is pre-configured to use `http://9router:20128/v1` inside Docker.

---

## ⚙️ Configuration

Edit `.env` to customize:

```env
TZ=America/Sao_Paulo
ROUTER_PORT=20128
HERMES_DASHBOARD_PORT=4999
HERMES_DASHBOARD_PASSWORD=   # optional, secures the dashboard
HERMES_DEFAULT_MODEL=gemini-2.0-flash
TELEGRAM_BOT_TOKEN=          # optional
DISCORD_BOT_TOKEN=           # optional
```

---

## 📊 Useful Commands

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View real-time logs
docker compose logs -f

# View 9router logs only
docker compose logs -f 9router

# View Hermes logs only
docker compose logs -f hermes

# Restart a single service
docker compose restart 9router

# Pull latest images and restart
docker compose pull && docker compose up -d

# Open Hermes dashboard (in browser)
open http://localhost:4999
```

---

## 🔒 Security Notes

- The Hermes dashboard (`4999`) is **bound to `127.0.0.1`** — not accessible from outside the machine.
- The dashboard stores API keys; **do not expose it on LAN without authentication**.
- For remote access, use an SSH tunnel: `ssh -L 4999:localhost:4999 your-server`

---

## 📚 References

- [Hermes Agent Docs](https://hermes-agent.nousresearch.com/docs/)
- [9Router GitHub](https://github.com/decolua/9router)
- [NousResearch Discord](https://discord.gg/NousResearch)
