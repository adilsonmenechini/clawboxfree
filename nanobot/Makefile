# ============================================================
# Clawbox — Nanobot Makefile
# Gerencia o Nanobot (gateway + API + CLI)
# ============================================================
#
# Uso:
#   make flow            # FLOW ÚNICO: sobe + onboard + setup + acessos
#   make up              # só sobe gateway + API
#   make down            # remove containers
#   make agent           # CLI agente interativo
#   make onboard         # configuração inicial
#   make setup           # configura provider 9router
#   make status          # status do nanobot
#   make logs
# ============================================================

COMPOSE := docker compose -p clawbox

.PHONY: help up down agent onboard setup flow status gateway-config logs ps build pull config

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

up: ## Sobe o Nanobot gateway + API
	$(COMPOSE) up -d --build

down: ## Remove containers (volume preservado)
	$(COMPOSE) down

agent: ## CLI interativo do Nanobot (modo agente)
	$(COMPOSE) run --rm nanobot-cli agent

onboard: ## Inicializa configuração do Nanobot
	@# Primeira tentativa; se pedir confirmação (config já existe), responde y
	@if $(COMPOSE) run --rm nanobot-cli onboard -c /home/nanobot/.nanobot/config.json 2>/dev/null; then \
		:; \
	else \
		echo "y" | $(COMPOSE) run --rm nanobot-cli onboard -c /home/nanobot/.nanobot/config.json 2>/dev/null || true; \
	fi
	@echo "Onboard concluído"

setup: scripts/nanobot-setup.sh ## Configura provider 9router no Nanobot
	@bash scripts/nanobot-setup.sh

flow: ## FLOW ÚNICO: build → onboard → setup 9router → sobe gateway+api
	@echo "============================================"
	@echo " 🐾 Clawbox - Nanobot Unified Flow"
	@echo "============================================"
	@echo ""
	@echo "=== 1/5 Garantindo .env ==="
	@if [ ! -f .env ]; then cp .env.example .env; echo "  [criado .env de .env.example]"; else echo "  [.env já existe]"; fi
	@echo ""
	@echo "=== 2/5 Build da imagem ==="
	$(MAKE) build
	@echo ""
	@echo "=== 3/5 Onboarding (config inicial) ==="
	$(MAKE) onboard
	@echo ""
	@echo "=== 4/5 Configurando provider 9router ==="
	$(MAKE) setup
	@echo ""
	@echo "=== 5/5 Subindo gateway + API ==="
	$(COMPOSE) up -d
	@sleep 3
	@echo ""
	@echo "=== Acessos ==="
	@echo "  Gateway HTTP:  http://127.0.0.1:$$(grep -m1 '^NANOBOT_GW_HTTP_PORT=' .env 2>/dev/null | cut -d= -f2- || echo 8765)"
	@echo "  Gateway WS:    ws://127.0.0.1:$$(grep -m1 '^NANOBOT_GW_WS_PORT=' .env 2>/dev/null | cut -d= -f2- || echo 18790)"
	@echo "  API Server:    http://127.0.0.1:$$(grep -m1 '^NANOBOT_API_PORT=' .env 2>/dev/null | cut -d= -f2- || echo 8900)"
	@echo "  CLI:           make nanobot-agent"
	@echo "============================================"

status: ## Status do Nanobot
	$(COMPOSE) run --rm nanobot-cli status

gateway-config: ## Mostra a config atual do gateway
	$(COMPOSE) exec nanobot-gateway nanobot gateway --show-config 2>/dev/null || \
		$(COMPOSE) exec nanobot-gateway cat /home/nanobot/.nanobot/config.json 2>/dev/null || \
		echo "Gateway não está rodando ou config não encontrada"

logs: ## Segue logs (svc=<nome>; default: todos)
	$(COMPOSE) logs -f $(svc)

ps: ## Lista containers
	$(COMPOSE) ps

build: ## Rebuilda imagem local
	$(COMPOSE) build

pull: ## Puxa imagem atualizada (se image: definida)
	$(COMPOSE) pull

config: ## Valida e mostra o compose resolvido
	$(COMPOSE) config
