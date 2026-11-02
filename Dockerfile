FROM python:3.13-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    TZ=Europe/Bratislava

# apt-get upgrade: bezpečnostné opravy Debianu aj keď python:slim mešká; curl pre healthcheck
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --no-install-recommends \
 && apt-get install -y --no-install-recommends ca-certificates curl tzdata \
 && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.8 /uv /usr/local/bin/uv

WORKDIR /app
COPY pyproject.toml uv.lock README.md ./
RUN uv sync --frozen --no-dev --no-install-project
COPY src ./src
COPY entrypoint.sh ./
RUN uv sync --frozen --no-dev && chmod 0555 /app/entrypoint.sh

ENV PATH="/app/.venv/bin:$PATH"
# Ne-root: uid/gid 1000 = vlastník vaultu na hostiteľovi (fifteen); vault je pripojený read-only na /vault.
USER 1000:1000
EXPOSE 8000

# unhealthy aj keď vault nie je pripojený ("vault": false), nie len keď server nebeží
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8000/healthz | grep -q '"vault": true' || exit 1

CMD ["/app/entrypoint.sh"]
