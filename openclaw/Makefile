# ============================================================
# Clawbox — OpenClaw Makefile
# Gerencia o OpenClaw (gateway + CLI)
# ============================================================
#
# Uso:
#   make up             # sobe o gateway
#   make down           # remove
#   make onboard        # onboarding inicial
#   make setup          # configura provider 9router
#   make logs
# ============================================================

COMPOSE := docker compose -p clawbox

.PHONY: help up down onboard setup logs ps build pull config

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up: ## Sobe o OpenClaw gateway
	$(COMPOSE) up -d

down: ## Remove containers (volume preservado)
	$(COMPOSE) down

onboard: ## Onboarding inicial do OpenClaw
	$(COMPOSE) run --rm openclaw-cli onboard

setup: scripts/openclaw-setup.sh ## Configura provider 9router no OpenClaw
	@bash scripts/openclaw-setup.sh

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
