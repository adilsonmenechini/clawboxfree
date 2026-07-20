# ============================================================
# Clawbox — Hermes Makefile
# Gerencia o Hermes Agent (gateway + dashboard)
# ============================================================
#
# Uso:
#   make flow       # FLOW ÚNICO: sobe com garantias
#   make up         # só sobe
#   make down       # remove
#   make logs
# ============================================================

COMPOSE := docker compose -p clawbox

DASHBOARD_PORT := $(shell grep -m1 '^HERMES_DASHBOARD_PORT=' .env 2>/dev/null | cut -d= -f2- || echo "4999")

.PHONY: help up down flow logs ps build pull config

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up: ## Sobe o Hermes Agent
	$(COMPOSE) up -d --build

down: ## Remove o container (volume preservado)
	$(COMPOSE) down

flow: ## FLOW ÚNICO: garante .env → sobe → mostra acesso
	@echo "============================================"
	@echo " 🐾 Clawbox - Hermes Unified Flow"
	@echo "============================================"
	@echo ""
	@echo "=== 1/2 Garantindo .env ==="
	@if [ ! -f .env ]; then cp .env.example .env; echo "  [criado .env de .env.example]"; else echo "  [.env já existe]"; fi
	@echo ""
	@echo "=== 2/2 Subindo Hermes ==="
	$(COMPOSE) up -d --build
	@sleep 2
	@echo ""
	@echo "=== Acessos ==="
	@echo "  Dashboard: http://127.0.0.1:$(DASHBOARD_PORT)"
	@echo "============================================"

logs: ## Segue logs (svc=<nome>; default: todos)
	$(COMPOSE) logs -f $(svc)

ps: ## Lista containers
	$(COMPOSE) ps

build: ## Rebuilda imagem local
	$(COMPOSE) build

pull: ## Puxa imagem atualizada
	$(COMPOSE) pull

config: ## Valida e mostra o compose resolvido
	$(COMPOSE) config
