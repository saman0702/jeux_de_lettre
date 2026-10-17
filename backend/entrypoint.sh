#!/bin/sh
# Démarre l'API : vérifie Postgres, applique les migrations, lance uvicorn.
set -eu

echo "[entrypoint] Letter Race API — démarrage"

if [ -z "${DATABASE_URL:-}" ]; then
  echo "[entrypoint] ERREUR: DATABASE_URL manquant (variable Dokploy / --env-file)." >&2
  exit 1
fi

if [ -z "${REDIS_URL:-}" ]; then
  echo "[entrypoint] ERREUR: REDIS_URL manquant (ex: redis://redis:6379/0)." >&2
  exit 1
fi

echo "[entrypoint] Test connexion Postgres…"
python - <<'PY'
import asyncio
import os
import sys
from urllib.parse import urlparse

import asyncpg

raw = os.environ["DATABASE_URL"]
# asyncpg attend postgresql:// (pas +asyncpg)
url = raw.replace("postgresql+asyncpg://", "postgresql://", 1)
parsed = urlparse(url)
host = parsed.hostname or "?"
port = parsed.port or 5432
db = (parsed.path or "/").lstrip("/") or "?"
user = parsed.username or "?"

async def main() -> None:
    try:
        conn = await asyncpg.connect(url, timeout=20)
        await conn.fetchval("SELECT 1")
        await conn.close()
    except Exception as exc:
        print(
            f"[entrypoint] ERREUR Postgres ({user}@{host}:{port}/{db}): {exc}",
            file=sys.stderr,
        )
        print(
            "[entrypoint] Corrige DATABASE_URL (mot de passe / hôte / firewall) puis redéploie.",
            file=sys.stderr,
        )
        sys.exit(1)

asyncio.run(main())
print(f"[entrypoint] Postgres OK — {user}@{host}:{port}/{db}")
PY

echo "[entrypoint] Migrations Alembic…"
alembic upgrade head
echo "[entrypoint] Migrations OK"

echo "[entrypoint] Uvicorn :8000"
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --proxy-headers --forwarded-allow-ips='*'
