# Plan : carrière du QI

À faire après le lancement, comme première mise à jour. Statut : **pas commencé**.

## But

Donner au joueur solo une raison de revenir au QI : une carte de niveaux à avancer, des étoiles à décrocher, des pièces à gagner. Aujourd'hui, le QI solo n'a que le solo libre (sans but) et le défi du jour (une fois par jour).

## Le jeu

### Mondes et niveaux

30 niveaux en 3 mondes de 10, 5 énigmes par niveau (le niveau 10 de chaque monde est un « boss » de 8 énigmes).

| Monde | Niveaux | Difficulté des énigmes | Temps par énigme | Types mis en avant |
|---|---|---|---|---|
| 1. Éveil | 1 à 10 | facile (niveau 1), un peu de moyen à la fin | 45 s | suites, calcul simple, intrus, calendrier |
| 2. Réflexion | 11 à 20 | moyen (niveau 2), un peu de difficile à la fin | 30 s | analogies, grilles, schémas (matrices, rotations), un seul trait |
| 3. Génie | 21 à 30 | difficile (niveau 3) | 20 s | tout, dont les schémas et tracés difficiles |

- Chaque niveau mélange les types (jamais 5 fois le même), sans répéter une énigme déjà vue dans le niveau.
- Un niveau est **le même pour tous** : énigmes tirées d'une graine fixe (`iq-career-<niveau>`), comme le défi du jour. On peut alors le rejouer pour faire mieux, et comparer avec ses amis.
- Bonus de rapidité activé, pas de malus.

### Étoiles et déblocage

- 1 étoile : 3 bonnes réponses sur 5 (5 sur 8 pour un boss).
- 2 étoiles : 4 sur 5 (6 sur 8).
- 3 étoiles : 5 sur 5 (8 sur 8), ou 4 sur 5 avec un score de rapidité élevé (à régler en jouant).
- Le niveau suivant s'ouvre avec au moins 1 étoile. On garde le meilleur résultat.
- Le monde suivant s'ouvre quand le boss du monde est réussi.

### Pièces

- Les points rapportent des pièces comme ailleurs (20 points = 1 pièce).
- Bonus la **première fois** qu'on obtient chaque étoile d'un niveau : +2 pièces par étoile, +10 pour la 3e étoile d'un boss.
- Rejouer un niveau déjà à 3 étoiles ne rapporte que les points (pas de bonus) : on ne peut pas « farmer ».

### Jokers

Les jokers payants du QI (50/50, indice, +15 s, passer) sont autorisés, sauf dans les boss.

## Ce qui existe déjà et qu'on réutilise

- **Parties vérifiées par le serveur** : `backend/app/services/iq_play_service.py` (énigmes gardées en base, temps mesuré par le serveur, jokers, points → pièces). La carrière y ajoute un mode `career`.
- **Tirage avec graine** : `daily_puzzles(day)` dans le même fichier sert de modèle pour `career_puzzles(level)`.
- **Écrans** : `mobile/lib/features/iq/iq_solo_screen.dart` (déroulé d'une partie, jokers, correction, résultat) et `mobile/lib/features/iq/iq_run.dart` (`ServerIqRun`).
- **Carte de carrière** : `mobile/lib/features/career/career_screen.dart` et `career_levels.dart` (Petit Bac) : même présentation (mondes, cases de niveaux, étoiles, cadenas).

## Ce qu'il faut ajouter

### Serveur

1. **Règles des niveaux** : `backend/app/services/iq_career_service.py`. Pour chaque niveau : nombre d'énigmes, temps, niveau(x) de difficulté, types favoris, seuils d'étoiles, boss ou non.
2. **Progression en base** : table `iq_career_progress` (`client_id`, `level`, `best_stars`, `best_score`, `stars_rewarded`, `updated_at`), avec migration Alembic. Elle est gardée sur le serveur (contrairement au Petit Bac, gardé sur le téléphone) parce que les niveaux rapportent des pièces, et qu'elle survit ainsi à une réinstallation.
3. **Mode `career`** dans `IqSession` : colonne `career_level` (nullable).
4. **Routes** (jeton secret exigé, comme le reste du QI) :
   - `GET /api/v1/iq/career?client_id=` : la carte (étoiles par niveau, niveaux ouverts) ;
   - `POST /api/v1/iq/career/{level}` : démarre un niveau (refusé si pas encore ouvert) ;
   - les réponses, l'énigme suivante et les jokers passent par les routes `sessions/{id}/…` qui existent déjà ;
   - à la dernière énigme, la réponse inclut les étoiles obtenues, les pièces de bonus et le niveau débloqué.
5. **Tests** : niveaux identiques pour tous (graine), seuils d'étoiles, déblocage, bonus versé une seule fois, niveau fermé refusé, jokers refusés en boss.

### Appli

1. **Carte de carrière QI** (`mobile/lib/features/iq/iq_career_screen.dart`), sur le modèle de celle du Petit Bac : 3 mondes, 30 cases, étoiles, cadenas, fond QI.
2. **Entrée** : un bouton « CARRIÈRE » dans l'espace QI (à côté du défi du jour). Il faut être en ligne, comme pour le défi du jour.
3. **Partie** : `IqSoloScreen` en mode carrière (`ServerIqRun.career(level)`), avec l'objectif affiché (« 3 bonnes réponses pour 1 étoile »).
4. **Fin de niveau** : étoiles animées, pièces gagnées, boutons « NIVEAU SUIVANT » et « REJOUER ».
5. **Textes** FR et EN, et tests de widgets (carte, déblocage, fin de niveau).

## Étapes proposées

1. Serveur : règles des niveaux et tirage avec graine, puis la table et la migration.
2. Serveur : routes et tests.
3. Appli : carte de carrière et entrée dans l'espace QI.
4. Appli : partie en mode carrière, puis écran de fin.
5. Réglage : jouer les 30 niveaux, ajuster les temps et les seuils d'étoiles.
6. Doc : nouvelles entrées dans `docs/DECISIONS.md`.

## Questions à trancher avant de commencer

- Les noms des mondes (« Éveil / Réflexion / Génie » ou autre).
- La carrière se joue-t-elle aussi hors ligne (sans pièces, progression sur le téléphone) ou seulement en ligne ?
- Ajouter plus tard un classement des étoiles entre amis ?
