# ============================================================
# Clawbox — Providers Makefile
# Gerencia 9Router + Headroom + Docker-in-Docker
# ============================================================
#
# Uso:
#   make up        # sobe todos
#   make down      # remove todos
#   make logs svc=9router
# ============================================================

COMPOSE := docker compose -p clawbox

.PHONY: help up down logs ps build pull config

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up: ## Sobe 9router + headroom + dind
	$(COMPOSE) up -d --build

down: ## Remove containers (volumes preservados)
	$(COMPOSE) down

logs: ## Segue logs (svc=<nome>; default: todos)
	$(COMPOSE) logs -f $(svc)

ps: ## Lista containers
	$(COMPOSE) ps

build: ## Rebuilda imagens locais
	$(COMPOSE) build

pull: ## Puxa imagens atualizadas
	$(COMPOSE) pull

config: ## Valida e mostra o compose resolvido
	$(COMPOSE) config
