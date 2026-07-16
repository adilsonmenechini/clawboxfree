# ============================================================
# Clawbox — OpenClaw Makefile
# Gerencia o OpenClaw (gateway + Control UI + proxy + CLI)
# ============================================================
#
# Uso:
#   make flow            # FLOW ÚNICO: sobe + onboard + setup + credenciais
#   make up              # só sobe gateway + proxy
#   make down            # remove containers
#   make onboard         # onboarding inicial
#   make setup           # configura provider 9router
#   make token           # mostra o gateway token
#   make logs
# ============================================================

COMPOSE := docker compose -p clawbox

.PHONY: help up down onboard setup flow logs ps build pull config token auth-password

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

up: ## Sobe o OpenClaw gateway + proxy
	$(COMPOSE) up -d --build

down: ## Remove containers (volumes preservados)
	$(COMPOSE) down

onboard: ## Onboarding inicial (automático, não-interativo)
	$(COMPOSE) run --rm openclaw-cli onboard --non-interactive --accept-risk --skip-health

setup: scripts/openclaw-setup.sh ## Configura provider 9router no OpenClaw
	@bash scripts/openclaw-setup.sh

flow: ## Flow único: sobe + onboard + setup + credenciais
	@echo "============================================"
	@echo " 🐾 Clawbox - OpenClaw Unified Flow"
	@echo "============================================"
	$(MAKE) up
	@echo ""
	@echo "=== 1/4 Onboarding ==="
	$(MAKE) onboard
	@echo ""
	@echo "=== 2/4 Configurando provider 9router ==="
	$(MAKE) setup
	@echo ""
	@echo "=== 3/4 Credenciais ==="
	$(MAKE) token
	$(MAKE) auth-password
	@echo ""
	@echo "=== 4/4 Acessos ==="
	@echo "  Proxy (recomendado): http://127.0.0.1:$$(grep -m1 '^OPENCLAW_PROXY_PORT=' .env 2>/dev/null | cut -d= -f2 || echo 8080)"
	@echo "  Gateway (direto):    http://127.0.0.1:$$(grep -m1 '^OPENCLAW_PORT=' .env 2>/dev/null | cut -d= -f2 || echo 18789)"
	@echo "============================================"

token: ## Mostra o gateway token (para a Control UI)
	@echo "Gateway token:"
	@$(COMPOSE) exec openclaw \
		sh -c "cat /home/node/.openclaw/openclaw.json | python3 -c \"import sys,json; print(json.load(sys.stdin)['gateway']['auth']['token'])\"" 2>/dev/null || \
		$(COMPOSE) exec openclaw \
		sh -c "cat /home/node/.openclaw/openclaw.json | grep -o '\"token\": *\"[^\"]*\"' | head -1 | cut -d'\"' -f4"

auth-password: ## Mostra a senha do basic auth do proxy
	@echo "Proxy auth:"; \
	PORT=8080; \
	if [ -f .env ] && grep -q '^OPENCLAW_PROXY_PORT=' .env 2>/dev/null; then \
		PORT=$$(grep '^OPENCLAW_PROXY_PORT=' .env | cut -d= -f2); \
	fi; \
	USER=admin; \
	if [ -f .env ] && grep -q '^OPENCLAW_AUTH_USERNAME=' .env 2>/dev/null; then \
		USER=$$(grep '^OPENCLAW_AUTH_USERNAME=' .env | cut -d= -f2); \
	fi; \
	PASS='<not set>'; \
	if [ -f .env ] && grep -q '^OPENCLAW_AUTH_PASSWORD=' .env 2>/dev/null; then \
		PASS=$$(grep '^OPENCLAW_AUTH_PASSWORD=' .env | cut -d= -f2); \
	fi; \
	echo "  URL:      http://127.0.0.1:$$PORT"; \
	echo "  Username: $$USER"; \
	echo "  Password: $$PASS"

logs: ## Segue logs (svc=<nome>; default: todos)
	$(COMPOSE) logs -f $(svc)

ps: ## Lista containers
	$(COMPOSE) ps

build: ## Rebuilda imagens
	$(COMPOSE) build

pull: ## Puxa imagens atualizadas
	$(COMPOSE) pull

config: ## Valida e mostra o compose resolvido
	$(COMPOSE) config
