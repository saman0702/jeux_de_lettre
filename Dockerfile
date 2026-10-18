# Dokploy / monorepo : contexte = racine du dépôt.
# Si le contexte est déjà backend/, utilise backend/Dockerfile à la place.
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

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/alembic.ini ./
COPY backend/migrations ./migrations
COPY backend/app ./app
COPY backend/entrypoint.sh ./entrypoint.sh

RUN chmod +x /code/entrypoint.sh \
    && mkdir -p /code/media \
    && chown -R appuser:appuser /code

USER appuser

EXPOSE 8000

# start-period long : premier boot peut seed ~200k answers
HEALTHCHECK --interval=30s --timeout=5s --start-period=300s --retries=5 \
    CMD curl -fsS http://127.0.0.1:8000/health || exit 1

CMD ["./entrypoint.sh"]
