# ============================================================
# Clawbox — Root Makefile (Orchestrator)
# Delega para os Makefiles individuais em providers/, hermes/, openclaw/
# ============================================================
#
# Uso:
#   make providers        # núcleo: 9router + headroom + dind
#   make hermes           # Hermes (gateway + dashboard)
#   make openclaw         # OpenClaw completo (onboard + setup + UI)
#   make openclaw-cli     # só o gateway
#   make all              # sobe tudo
#   make down             # remove tudo
#   make down-hermes      # só Hermes
#   make down-openclaw    # só OpenClaw
#   make logs svc=openclaw
# ============================================================

COMPOSE_PREFIX := docker compose -p clawbox
COMPOSE_PROVIDERS := -f providers/docker-compose.yml
COMPOSE_HERMES   := -f hermes/docker-compose.yml
COMPOSE_OPENCLAW := -f openclaw/docker-compose.yml

.PHONY: help providers hermes openclaw-cli openclaw-ui openclaw-onboard openclaw-setup openclaw all down down-hermes down-openclaw logs ps build pull config clean envs

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

providers: ## Núcleo: 9router + headroom + dind
	$(MAKE) -C providers up

hermes: ## Hermes (gateway + dashboard) — depende de providers
	$(MAKE) -C hermes up

openclaw-cli: ## OpenClaw gateway
	$(MAKE) -C openclaw up

openclaw-ui: ## Abre o Control UI do OpenClaw no navegador
	open http://127.0.0.1:18789

openclaw-onboard: ## Onboarding inicial do OpenClaw
	$(MAKE) -C openclaw onboard

openclaw-setup: ## Configura o provider 9router no OpenClaw
	$(MAKE) -C openclaw setup

openclaw: ## Configura todos as etapas do OpenClaw (onboard + setup)
	$(MAKE) -C openclaw up
	$(MAKE) -C openclaw onboard
	$(MAKE) -C openclaw setup
	open http://127.0.0.1:18789

all: ## Tudo (providers + hermes + openclaw)
	$(MAKE) providers
	$(MAKE) hermes
	$(MAKE) openclaw-cli

down: ## Remove tudo (containers + rede, volumes preservados)
	-$(MAKE) -C openclaw down 2>/dev/null || true
	-$(MAKE) -C hermes down 2>/dev/null || true
	-$(MAKE) -C providers down

down-hermes: ## Só Hermes
	-$(MAKE) -C hermes down 2>/dev/null || true

down-openclaw: ## Só OpenClaw
	-$(MAKE) -C openclaw down 2>/dev/null || true

envs: ## Cria os .env-* por serviço a partir dos exemplos (se não existirem)
	@for f in providers/.env hermes/.env openclaw/.env; do \
		example="$$f.example"; \
		if [ ! -f "$$f" ] && [ -f "$$example" ]; then \
			cp "$$example" "$$f" && echo "criado $$f"; \
		fi; \
	done

logs: ## Segue logs (svc=<nome>; default: todos)
	$(COMPOSE_PREFIX) $(COMPOSE_PROVIDERS) $(COMPOSE_HERMES) $(COMPOSE_OPENCLAW) logs -f $(svc)

ps: ## Lista containers
	$(COMPOSE_PREFIX) $(COMPOSE_PROVIDERS) $(COMPOSE_HERMES) $(COMPOSE_OPENCLAW) ps

build: ## Rebuilda imagens locais
	$(COMPOSE_PREFIX) $(COMPOSE_PROVIDERS) $(COMPOSE_HERMES) $(COMPOSE_OPENCLAW) build

pull: ## Puxa imagens atualizadas
	$(COMPOSE_PREFIX) $(COMPOSE_PROVIDERS) $(COMPOSE_HERMES) $(COMPOSE_OPENCLAW) pull

config: ## Valida e mostra todos os composes resolvidos
	$(COMPOSE_PREFIX) $(COMPOSE_PROVIDERS) $(COMPOSE_HERMES) $(COMPOSE_OPENCLAW) config

clean: ## Remove tudo (containers + rede + volumes)
	$(COMPOSE_PREFIX) $(COMPOSE_PROVIDERS) $(COMPOSE_HERMES) $(COMPOSE_OPENCLAW) down -v
