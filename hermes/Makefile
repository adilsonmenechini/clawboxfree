# ============================================================
# Clawbox — Hermes Makefile
# Gerencia o Hermes Agent (gateway + dashboard)
# ============================================================
#
# Uso:
#   make up        # sobe o Hermes
#   make down      # remove
#   make logs
# ============================================================

COMPOSE := docker compose -p clawbox

.PHONY: help up down logs ps build pull config

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up: ## Sobe o Hermes Agent
	$(COMPOSE) up -d --build

down: ## Remove o container (volume preservado)
	$(COMPOSE) down

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
