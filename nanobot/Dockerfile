FROM python:3.12-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        openssh-client \
        curl \
        && \
    rm -rf /var/lib/apt/lists/*

ARG NANOBOT_VERSION=latest
ARG NANOBOT_EXTRAS=api

RUN if [ "$NANOBOT_VERSION" = "latest" ]; then \
        pip install --no-cache-dir "nanobot-ai${NANOBOT_EXTRAS:+[$NANOBOT_EXTRAS]}"; \
    else \
        pip install --no-cache-dir "nanobot-ai${NANOBOT_EXTRAS:+[$NANOBOT_EXTRAS]}==${NANOBOT_VERSION}"; \
    fi

RUN groupadd -g 1000 nanobot && \
    useradd -m -u 1000 -g nanobot -s /bin/bash nanobot && \
    mkdir -p /home/nanobot/.nanobot && \
    chown -R nanobot:nanobot /home/nanobot

WORKDIR /home/nanobot
VOLUME /home/nanobot/.nanobot
EXPOSE 18790 8765 8900

ENTRYPOINT ["nanobot"]
CMD ["--help"]
