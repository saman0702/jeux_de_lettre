#!/bin/sh
# Vérifie Postgres → migrations → uvicorn (écoute 0.0.0.0:8000).
set -eu

echo "[entrypoint] Letter Race API — démarrage"
echo "[entrypoint] CMD: alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"

if [ -z "${DATABASE_URL:-}" ]; then
  echo "[entrypoint] ERREUR: DATABASE_URL manquant." >&2
  exit 1
fi

if [ -z "${REDIS_URL:-}" ]; then
  echo "[entrypoint] WARN: REDIS_URL absent → redis://127.0.0.1:6379/0 (souvent KO sur Dokploy)." >&2
  export REDIS_URL="redis://127.0.0.1:6379/0"
fi

echo "[entrypoint] Test connexion Postgres…"
python - <<'PY'
import asyncio
import os
import sys
from urllib.parse import urlparse

import asyncpg

raw = os.environ["DATABASE_URL"].strip()

# Corriger les formats courants mal saisis dans Dokploy
if raw.startswith("postgres://"):
    raw = "postgresql://" + raw.removeprefix("postgres://")
elif raw.startswith("postgresql+asyncpg://"):
    raw = "postgresql://" + raw.removeprefix("postgresql+asyncpg://")
elif "://" not in raw:
    # Ex: postgres:PASS@host:5433/db  →  postgresql://postgres:PASS@host:5433/db
    raw = "postgresql://" + raw
    print(
        "[entrypoint] WARN: schéma manquant dans DATABASE_URL — "
        "préfixe postgresql:// ajouté automatiquement.",
        file=sys.stderr,
    )

os.environ["DATABASE_URL"] = raw
parsed = urlparse(raw)
host = parsed.hostname or "?"
port = parsed.port or 5432
db = (parsed.path or "/").lstrip("/") or "?"
user = parsed.username or "?"

if not parsed.hostname or not parsed.username:
    print(
        "[entrypoint] ERREUR: DATABASE_URL invalide.",
        file=sys.stderr,
    )
    print(
        "  Attendu: postgresql://USER:PASSWORD@HOST:PORT/DB",
        file=sys.stderr,
    )
    print(f"  Reçu (masqué): {user}@{host}:{port}/{db}", file=sys.stderr)
    sys.exit(1)

async def main() -> None:
    try:
        conn = await asyncpg.connect(raw, timeout=20)
        await conn.fetchval("SELECT 1")
        await conn.close()
    except Exception as exc:
        print(
            f"[entrypoint] ERREUR Postgres ({user}@{host}:{port}/{db}): {exc}",
            file=sys.stderr,
        )
        sys.exit(1)

asyncio.run(main())
print(f"[entrypoint] Postgres OK — {user}@{host}:{port}/{db}")
PY

# Exporter l'URL éventuellement normalisée par le script Python
export DATABASE_URL="$(python - <<'PY'
import os
raw = os.environ["DATABASE_URL"].strip()
if raw.startswith("postgres://"):
    raw = "postgresql://" + raw.removeprefix("postgres://")
elif raw.startswith("postgresql+asyncpg://"):
    raw = "postgresql://" + raw.removeprefix("postgresql+asyncpg://")
elif "://" not in raw:
    raw = "postgresql://" + raw
print(raw)
PY
)"

echo "[entrypoint] Migrations Alembic…"
alembic upgrade head
echo "[entrypoint] Migrations OK"

echo "[entrypoint] Lancement uvicorn…"
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --proxy-headers --forwarded-allow-ips='*'
