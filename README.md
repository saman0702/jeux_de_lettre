# Letter Race

Jeu mobile de rapidité par lettres, inspiré du Petit Bac, en solo ou multijoueur temps réel.

- Cahier des charges : [docs/CAHIER_DES_CHARGES.md](docs/CAHIER_DES_CHARGES.md)
- Décisions : [docs/DECISIONS.md](docs/DECISIONS.md)

## Structure

```
backend/   API FastAPI (Python 3.12)
mobile/    Application Flutter (Android, iOS plus tard)
docs/      Documentation
```

## Démarrer le backend

```bash
cp .env.example .env        # puis choisir un mot de passe
docker compose up -d --build
docker compose exec api python -m app.data.seed_answers   # charge la base de réponses (≈ 207 000 entrées)
curl http://localhost:8010/health
```

Les migrations (Alembic) s'appliquent automatiquement au démarrage du conteneur `api`.
Après une modification des modèles : `cd backend && .venv/bin/alembic revision --autogenerate -m "..."`.

| Service    | URL                                   |
|------------|---------------------------------------|
| API        | http://localhost:8010                 |
| Swagger    | http://localhost:8010/docs            |
| PostgreSQL | `localhost:5432` (identifiants dans `.env`) |
| Redis      | `localhost:6379`                      |

### API solo

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/api/v1/config` | Options de partie (langues, catégories, manches, durées) |
| POST | `/api/v1/solo/games` | Crée une partie solo |
| GET | `/api/v1/solo/games/{id}` | État et historique de la partie |
| POST | `/api/v1/solo/games/{id}/rounds` | Démarre la manche suivante (le serveur tire la lettre) |
| POST | `/api/v1/solo/games/{id}/rounds/{n}/submit` | Envoie les réponses, renvoie validation et points |

### Temps réel (multijoueur)

WebSocket : `ws://localhost:8010/ws?client_id=<id>&nickname=<pseudo>`. Messages JSON `{"type": ...}` :
`quick_match`, `create_room`, `join_room`, `leave_room`, `set_ready`, `submit`, `subscribe_rooms` → le serveur répond par `welcome`, `online_count`, `room_list`, `room_state`, `notice`, `error`.
Détail dans `backend/app/services/room_service.py`.

Tests (utilisent une base `letterbattle_test` créée automatiquement, PostgreSQL doit tourner) :

```bash
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/pytest
```

## Lancer l'application mobile

```bash
cd mobile
flutter run                                   # émulateur Android → http://10.0.2.2:8010
flutter run --dart-define=API_BASE_URL=http://<IP-du-PC>:8010   # téléphone réel sur le même Wi-Fi
flutter test
```

L'application est disponible en français et en anglais (langue du téléphone).

Sons : `python3 mobile/tool/generate_sounds.py` régénère `mobile/assets/sounds/`.

Solo hors ligne : la base de réponses est embarquée dans l'appli. Après une modification des listes (`backend/app/data/seed/`), régénérer :
`cd backend && .venv/bin/python -m app.data.export_offline` (met à jour `mobile/assets/data/` et les cas de test).
