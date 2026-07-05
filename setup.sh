#!/usr/bin/env bash
# ============================================================
# setup.sh — Clawbox first-run helper
# ============================================================
# Este script autentica no GitHub Container Registry (GHCR)
# para permitir o download da imagem do Hermes Agent.
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
# ============================================================

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║        🐾  Clawbox Setup               ║${NC}"
echo -e "${BOLD}║   Hermes Agent + 9Router (Free AI)     ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Check dependencies ────────────────────────────────────────
for cmd in docker; do
  if ! command -v "$cmd" &>/dev/null; then
    echo -e "${RED}❌ '$cmd' não encontrado. Instale e tente novamente.${NC}"
    exit 1
  fi
done

# ── Check if docker compose plugin is available ───────────────
if ! docker compose version &>/dev/null; then
  echo -e "${RED}❌ 'docker compose' não encontrado. Certifique-se de ter Docker Desktop ou o plugin compose.${NC}"
  exit 1
fi

# ── Copy .env if needed ───────────────────────────────────────
if [ ! -f .env ]; then
  echo -e "${YELLOW}📋 Criando .env a partir de .env.example...${NC}"
  cp .env.example .env
  echo -e "${GREEN}✅ .env criado${NC}"
fi

echo ""
echo -e "${BOLD}━━━ Autenticação no GitHub Container Registry (GHCR) ━━━${NC}"
echo ""
echo -e "O Hermes Agent está hospedado em ${CYAN}ghcr.io/nousresearch/hermes-agent${NC}"
echo -e "É necessário um ${BOLD}GitHub Personal Access Token (PAT)${NC} para baixar a imagem."
echo ""
echo -e "${YELLOW}Como criar o token:${NC}"
echo -e "  1. Acesse: ${CYAN}https://github.com/settings/tokens/new${NC}"
echo -e "  2. Nome: clawbox-hermes (ou qualquer nome)"
echo -e "  3. Expiration: 90 days (ou No expiration)"
echo -e "  4. Scopes: marque apenas ${BOLD}read:packages${NC}"
echo -e "  5. Clique em 'Generate token' e copie o token"
echo ""

read -p "$(echo -e ${BOLD}"Seu GitHub username: "${NC})" GITHUB_USER
read -s -p "$(echo -e ${BOLD}"Cole o GitHub PAT (token): "${NC})" GITHUB_TOKEN
echo ""

if [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_TOKEN" ]; then
  echo -e "${RED}❌ Username ou token vazio. Abortando.${NC}"
  exit 1
fi

echo ""
echo -e "${YELLOW}🔐 Autenticando no GHCR...${NC}"
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin

echo ""
echo -e "${GREEN}✅ Autenticado no GHCR com sucesso!${NC}"
echo ""

# ── Pull images ───────────────────────────────────────────────
echo -e "${YELLOW}📦 Baixando imagens...${NC}"
echo ""

echo -e "${CYAN}→ decolua/9router:latest${NC}"
docker pull decolua/9router:latest

echo ""
echo -e "${CYAN}→ ghcr.io/nousresearch/hermes-agent:latest${NC}"
docker pull ghcr.io/nousresearch/hermes-agent:latest

echo ""
echo -e "${GREEN}✅ Imagens prontas!${NC}"
echo ""

# ── Start services ────────────────────────────────────────────
echo -e "${YELLOW}🚀 Iniciando Clawbox...${NC}"
docker compose up -d

echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║     🎉 Clawbox está rodando!            ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}9Router API:${NC}        http://localhost:20128/v1"
echo -e "  ${CYAN}Hermes Dashboard:${NC}   http://localhost:4999"
echo ""
echo -e "${YELLOW}Configure seu AI tool (Cursor, Claude Code, Cline…):${NC}"
echo -e "  Base URL:  ${BOLD}http://localhost:20128/v1${NC}"
echo -e "  API Key:   ${BOLD}sk-free-via-9router${NC}"
echo ""
echo -e "  Logs: ${CYAN}docker compose logs -f${NC}"
echo ""
