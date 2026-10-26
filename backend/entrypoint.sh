#!/bin/sh
# Vérifie Postgres → migrations → uvicorn.
set -eu

PORT="${PORT:-8000}"

echo "[entrypoint] Mind Race API — démarrage"
echo "[entrypoint] écoute 0.0.0.0:${PORT}"

if [ -z "${DATABASE_URL:-}" ]; then
  echo "[entrypoint] ERREUR: DATABASE_URL manquant." >&2
  exit 1
fi

if [ -z "${REDIS_URL:-}" ]; then
  echo "[entrypoint] WARN: REDIS_URL absent → redis://127.0.0.1:6379/0" >&2
  export REDIS_URL="redis://127.0.0.1:6379/0"
fi

mkdir -p "${MEDIA_DIR:-media}"

echo "[entrypoint] Test connexion Postgres…"
python - <<'PY'
import asyncio
import os
import sys
from urllib.parse import urlparse

import asyncpg

raw = os.environ["DATABASE_URL"].strip()

if raw.startswith("postgres://"):
    raw = "postgresql://" + raw.removeprefix("postgres://")
elif raw.startswith("postgresql+asyncpg://"):
    raw = "postgresql://" + raw.removeprefix("postgresql+asyncpg://")
elif "://" not in raw:
    # Ex: postgres:PASS@host:5433/db
    raw = "postgresql://" + raw
    print(
        "[entrypoint] WARN: schéma manquant — postgresql:// ajouté.",
        file=sys.stderr,
    )

os.environ["DATABASE_URL"] = raw
parsed = urlparse(raw)
host = parsed.hostname or "?"
port = parsed.port or 5432
db = (parsed.path or "/").lstrip("/") or "?"
user = parsed.username or "?"

if not parsed.hostname or not parsed.username:
    print("[entrypoint] ERREUR: DATABASE_URL invalide.", file=sys.stderr)
    print("  Attendu: postgresql://USER:PASSWORD@HOST:PORT/DB", file=sys.stderr)
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

# Seul jeu de données à charger en base : answers (pays, animaux, fruits, villes, prénoms).
# Boutique / cosmétiques = code ; facts = fichier facts.json.gz (pas de table).
echo "[entrypoint] Vérification seed answers…"
NEED_SEED="$(python - <<'PY'
import asyncio, os
import asyncpg
url = os.environ["DATABASE_URL"].replace("postgresql+asyncpg://", "postgresql://", 1)
async def main():
    conn = await asyncpg.connect(url, timeout=20)
    try:
        n = await conn.fetchval("SELECT count(*) FROM answers")
    except Exception:
        n = 0
    await conn.close()
    print("1" if not n else "0")
asyncio.run(main())
PY
)"
if [ "$NEED_SEED" = "1" ]; then
  echo "[entrypoint] answers vide → seed complet (téléchargements + insert, quelques minutes)…"
  python -m app.data.seed_answers
  echo "[entrypoint] Seed OK"
else
  echo "[entrypoint] answers déjà présentes — seed ignoré"
fi

echo "[entrypoint] Lancement uvicorn :${PORT}"
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT}" --proxy-headers --forwarded-allow-ips='*'
