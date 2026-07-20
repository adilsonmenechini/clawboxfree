# ============================================================
# Clawbox — Root Makefile (Orchestrator)
# Delega para os Makefiles individuais em providers/, hermes/, openclaw/, nanobot/
# ============================================================
#
# Uso:
#   make openclaw         # FLOW ÚNICO: sobe + onboard + setup + credenciais
#   make providers        # núcleo: 9router + headroom + dind
#   make hermes           # Hermes (gateway + dashboard)
#   make nanobot          # FLOW ÚNICO: sobe + onboard + setup + acessos
#   make nanobot-up       # só sobe gateway + API
#   make nanobot-agent    # CLI do Nanobot (modo agente)
#   make all              # sobe tudo
#   make down             # remove tudo
#   make logs svc=openclaw
# ============================================================

COMPOSE_PREFIX := docker compose -p clawbox
COMPOSE_PROVIDERS := -f providers/docker-compose.yml
COMPOSE_HERMES   := -f hermes/docker-compose.yml
COMPOSE_OPENCLAW := -f openclaw/docker-compose.yml
COMPOSE_NANOBOT  := -f nanobot/docker-compose.yml

.PHONY: help providers hermes openclaw-cli openclaw-ui openclaw-token openclaw-auth openclaw-onboard openclaw-setup openclaw nanobot nanobot-up nanobot-gateway nanobot-api nanobot-agent nanobot-onboard nanobot-setup nanobot-status nanobot-gateway-config sync-provider all down down-hermes down-openclaw down-nanobot logs ps build pull config clean envs

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

providers: ## Núcleo: 9router + headroom + dind
	$(MAKE) -C providers up

hermes: ## FLOW ÚNICO: garante .env → sobe Hermes
	$(MAKE) -C hermes flow

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

openclaw-setup: ## Configura o provider 9router no OpenClaw + sincroniza .env-provider
	$(MAKE) -C openclaw setup
	bash scripts/sync-provider.sh

openclaw: ## FLOW ÚNICO: sobe + onboard + setup + sync-provider + credenciais + abre navegador
	@echo "============================================"
	@echo " 🐾 Clawbox - OpenClaw Unified Flow"
	@echo "============================================"
	$(MAKE) -C openclaw up
	@echo ""
	@echo "=== 1/5 Onboarding ==="
	$(MAKE) -C openclaw onboard
	@echo ""
	@echo "=== 2/5 Configurando provider 9router ==="
	$(MAKE) -C openclaw setup
	@echo ""
	@echo "=== 3/5 Sincronizando provider central (.env-provider) ==="
	bash scripts/sync-provider.sh
	@echo ""
	@echo "=== 4/5 Credenciais ==="
	$(MAKE) openclaw-token
	$(MAKE) openclaw-auth
	@echo ""
	@echo "=== 5/5 Acessos ==="
	@echo "  Proxy (recomendado): http://127.0.0.1:${OPENCLAW_PROXY_PORT:-8080}"
	@echo "  Gateway (direto):    http://127.0.0.1:${OPENCLAW_PORT:-18789}"
	@echo "============================================"
	open http://127.0.0.1:${OPENCLAW_PROXY_PORT:-8080}

# ── Nanobot ────────────────────────────────────────────────
nanobot: ## FLOW ÚNICO: sobe + onboard + setup + acessos
	$(MAKE) -C nanobot flow

nanobot-up: ## Só sobe Nanobot (gateway + API)
	$(MAKE) -C nanobot up

nanobot-gateway: ## Só o gateway Nanobot
	$(COMPOSE_PREFIX) $(COMPOSE_NANOBOT) up -d nanobot-gateway

nanobot-api: ## Só o API server Nanobot
	$(COMPOSE_PREFIX) $(COMPOSE_NANOBOT) up -d nanobot-api

nanobot-agent: ## CLI agente interativo
	$(MAKE) -C nanobot agent

nanobot-onboard: ## Inicializa configuração do Nanobot
	$(MAKE) -C nanobot onboard

nanobot-setup: ## Configura provider 9router no Nanobot
	$(MAKE) -C nanobot setup

nanobot-status: ## Status do Nanobot
	$(COMPOSE_PREFIX) $(COMPOSE_NANOBOT) run --rm nanobot-cli status

nanobot-gateway-config: ## Config atual do gateway
	$(COMPOSE_PREFIX) $(COMPOSE_NANOBOT) exec nanobot-gateway nanobot gateway --show-config 2>/dev/null || \
		$(COMPOSE_PREFIX) $(COMPOSE_NANOBOT) exec nanobot-gateway cat /home/nanobot/.nanobot/config.json 2>/dev/null || \
		echo "Gateway não está rodando ou config não encontrada"

sync-provider: ## Extrai chave real do 9router e atualiza .env-provider
	bash scripts/sync-provider.sh

all: ## Tudo (envs + providers + hermes + openclaw + nanobot)
	$(MAKE) envs
	$(MAKE) providers
	$(MAKE) hermes
	$(MAKE) openclaw-cli
	$(MAKE) nanobot

down: ## Remove tudo (containers + rede, volumes preservados)
	-$(MAKE) -C nanobot down 2>/dev/null || true
	-$(MAKE) -C openclaw down 2>/dev/null || true
	-$(MAKE) -C hermes down 2>/dev/null || true
	-$(MAKE) -C providers down

down-hermes: ## Só Hermes
	-$(MAKE) -C hermes down 2>/dev/null || true

down-openclaw: ## Só OpenClaw
	-$(MAKE) -C openclaw down 2>/dev/null || true

down-nanobot: ## Só Nanobot
	-$(MAKE) -C nanobot down 2>/dev/null || true

envs: ## Cria .env-provider + .env de cada stack com merge de provider vars
	@# Garante .env-provider
	@if [ ! -f .env-provider ]; then \
		if [ -f .env-provider.example ]; then \
			cp .env-provider.example .env-provider && echo "criado .env-provider"; \
		else \
			echo "PROVIDER_BASE_URL=http://9router:20128/v1" > .env-provider; \
			echo "PROVIDER_API_KEY=sk-free-via-9router" >> .env-provider; \
			echo "PROVIDER_MODEL=gpt-4o-mini" >> .env-provider; \
			echo "criado .env-provider (default)"; \
		fi; \
	fi
	@# Lê provider vars centrais
	@PBASE=$$(grep '^PROVIDER_BASE_URL=' .env-provider 2>/dev/null | cut -d= -f2-); \
	PKEY=$$(grep '^PROVIDER_API_KEY=' .env-provider 2>/dev/null | cut -d= -f2-); \
	PMOD=$$(grep '^PROVIDER_MODEL=' .env-provider 2>/dev/null | cut -d= -f2-); \
	[ -z "$$PBASE" ] && PBASE="http://9router:20128/v1"; \
	[ -z "$$PKEY" ] && PKEY="sk-free-via-9router"; \
	[ -z "$$PMOD" ] && PMOD="gpt-4o-mini"; \
	merge_var() { \
		f="$$1"; var="$$2"; val="$$3"; \
		if grep -q "^$$var=" "$$f" 2>/dev/null; then \
			sed -i '' "s|^$$var=.*|$$var=$$val|" "$$f"; \
		else \
			echo "$$var=$$val" >> "$$f"; \
		fi; \
	}; \
	for f in providers/.env hermes/.env openclaw/.env nanobot/.env; do \
		stack=$$(dirname $$f); \
		example="$$f.example"; \
		if [ ! -f "$$f" ] && [ -f "$$example" ]; then \
			cp "$$example" "$$f" && echo "criado $$f"; \
		fi; \
		[ ! -f "$$f" ] && continue; \
		case "$$stack" in \
			hermes) \
				merge_var "$$f" "OPENAI_BASE_URL" "$$PBASE"; \
				merge_var "$$f" "OPENAI_API_KEY" "$$PKEY"; \
				merge_var "$$f" "HERMES_BASE_URL" "$$PBASE"; \
				merge_var "$$f" "HERMES_API_KEY" "$$PKEY"; \
				merge_var "$$f" "HERMES_DEFAULT_MODEL" "$$PMOD"; \
				;; \
			openclaw) \
				merge_var "$$f" "ROUTER_9_API_KEY" "$$PKEY"; \
				;; \
			nanobot) \
				merge_var "$$f" "OPENAI_BASE_URL" "$$PBASE"; \
				merge_var "$$f" "OPENAI_API_KEY" "$$PKEY"; \
				;; \
		esac; \
	done
	@echo "envs concluído — provider vars propagadas para todos os stacks"

logs: ## Segue logs (svc=<nome>; default: todos)
	$(COMPOSE_PREFIX) $(COMPOSE_PROVIDERS) $(COMPOSE_HERMES) $(COMPOSE_OPENCLAW) $(COMPOSE_NANOBOT) logs -f $(svc)

ps: ## Lista containers
	$(COMPOSE_PREFIX) $(COMPOSE_PROVIDERS) $(COMPOSE_HERMES) $(COMPOSE_OPENCLAW) $(COMPOSE_NANOBOT) ps

build: ## Rebuilda imagens locais
	$(COMPOSE_PREFIX) $(COMPOSE_PROVIDERS) $(COMPOSE_HERMES) $(COMPOSE_OPENCLAW) $(COMPOSE_NANOBOT) build

pull: ## Puxa imagens atualizadas
	$(COMPOSE_PREFIX) $(COMPOSE_PROVIDERS) $(COMPOSE_HERMES) $(COMPOSE_OPENCLAW) $(COMPOSE_NANOBOT) pull

config: ## Valida e mostra todos os composes resolvidos
	$(COMPOSE_PREFIX) $(COMPOSE_PROVIDERS) $(COMPOSE_HERMES) $(COMPOSE_OPENCLAW) $(COMPOSE_NANOBOT) config

clean: ## Remove tudo (containers + rede + volumes)
	$(COMPOSE_PREFIX) $(COMPOSE_PROVIDERS) $(COMPOSE_HERMES) $(COMPOSE_OPENCLAW) $(COMPOSE_NANOBOT) down -v --remove-orphans
