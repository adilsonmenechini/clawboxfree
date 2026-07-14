FROM nousresearch/hermes-agent:latest

USER root

# Docker CLI para sandbox DinD
RUN apt-get update -qq && apt-get install -y --no-install-recommends docker.io && rm -rf /var/lib/apt/lists/*

# SOUL.md — identidade SRE Sênior
# Seed no volume /opt/data para primeira execução
COPY .hermes/SOUL.md /opt/data/SOUL.md
RUN chown hermes:hermes /opt/data/SOUL.md

USER hermes
