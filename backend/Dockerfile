# Mind Race API — image de production
# Domaine : https://gamelr-api.optisoftw.com
#
# Build (contexte = ce dossier) :
#   docker build -t letterrace-api ./backend
# Dokploy monorepo (contexte = racine) : utiliser le Dockerfile à la racine.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8000

WORKDIR /code

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 1000 --shell /usr/sbin/nologin appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY alembic.ini ./
COPY migrations ./migrations
COPY app ./app
COPY entrypoint.sh ./entrypoint.sh

RUN chmod +x /code/entrypoint.sh \
    && mkdir -p /code/media \
    && chown -R appuser:appuser /code

USER appuser

EXPOSE 8000

# start-period long : premier boot peut seed ~200k answers
HEALTHCHECK --interval=30s --timeout=5s --start-period=300s --retries=5 \
    CMD curl -fsS http://127.0.0.1:8000/health || exit 1

# check DB → alembic → uvicorn (PORT défaut 8000 — même port dans Dokploy)
CMD ["./entrypoint.sh"]
