# Letter Race API — image de production
# Domaine : https://gamelr-api.optisoftw.com
#
# Build :
#   docker build -t letterrace-api ./backend
# Run (env hors image, pas de compose) :
#   docker build -t letterrace-api ./backend
#   docker run -d --name letterrace-api \
#     --env-file backend/.env.production \
#     --add-host=host.docker.internal:host-gateway \
#     -p 8000:8000 -v letterrace-media:/code/media letterrace-api
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

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

RUN mkdir -p /code/media \
    && chown -R appuser:appuser /code

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8000/health || exit 1

# Migrations au démarrage, puis API derrière un reverse-proxy HTTPS.
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000 --proxy-headers --forwarded-allow-ips='*'"]
