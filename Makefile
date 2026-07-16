# ============================================================
# Clawbox — Root Makefile (Orchestrator)
# Delega para os Makefiles individuais em providers/, hermes/, openclaw/
# ============================================================
#
# Uso:
#   make openclaw         # FLOW ÚNICO: sobe + onboard + setup + credenciais
#   make providers        # núcleo: 9router + headroom + dind
#   make hermes           # Hermes (gateway + dashboard)
#   make all              # sobe tudo
#   make down             # remove tudo
#   make logs svc=openclaw
# ============================================================

COMPOSE_PREFIX := docker compose -p clawbox
COMPOSE_PROVIDERS := -f providers/docker-compose.yml
COMPOSE_HERMES   := -f hermes/docker-compose.yml
COMPOSE_OPENCLAW := -f openclaw/docker-compose.yml

.PHONY: help providers hermes openclaw-cli openclaw-ui openclaw-token openclaw-auth openclaw-onboard openclaw-setup openclaw all down down-hermes down-openclaw logs ps build pull config clean envs

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

providers: ## Núcleo: 9router + headroom + dind
	$(MAKE) -C providers up

hermes: ## Hermes (gateway + dashboard) — depende de providers
	$(MAKE) -C hermes up

openclaw-cli: ## OpenClaw gateway
	$(MAKE) -C openclaw up

openclaw-ui: ## Abre o Control UI do OpenClaw via proxy (porta 8080)
	open http://127.0.0.1:${OPENCLAW_PROXY_PORT:-8080}

openclaw-token: ## Mostra o gateway token
	$(MAKE) -C openclaw token

openclaw-auth: ## Mostra credenciais do proxy
	$(MAKE) -C openclaw auth-password

openclaw-onboard: ## Onboarding inicial do OpenClaw
	$(MAKE) -C openclaw onboard

openclaw-setup: ## Configura o provider 9router no OpenClaw
	$(MAKE) -C openclaw setup

openclaw: ## FLOW ÚNICO: sobe + onboard + setup + credenciais + abre navegador
	@echo "============================================"
	@echo " 🐾 Clawbox - OpenClaw Unified Flow"
	@echo "============================================"
	$(MAKE) -C openclaw up
	@echo ""
	@echo "=== 1/4 Onboarding ==="
	$(MAKE) -C openclaw onboard
	@echo ""
	@echo "=== 2/4 Configurando provider 9router ==="
	$(MAKE) -C openclaw setup
	@echo ""
	@echo "=== 3/4 Credenciais ==="
	$(MAKE) openclaw-token
	$(MAKE) openclaw-auth
	@echo ""
	@echo "=== 4/4 Acessos ==="
	@echo "  Proxy (recomendado): http://127.0.0.1:${OPENCLAW_PROXY_PORT:-8080}"
	@echo "  Gateway (direto):    http://127.0.0.1:${OPENCLAW_PORT:-18789}"
	@echo "============================================"
	open http://127.0.0.1:${OPENCLAW_PROXY_PORT:-8080}

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
	$(COMPOSE_PREFIX) $(COMPOSE_PROVIDERS) $(COMPOSE_HERMES) $(COMPOSE_OPENCLAW) down -v --remove-orphans
