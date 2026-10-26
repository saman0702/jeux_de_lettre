# Cahier des charges — Jeu de rapidité par lettres

## 1. Présentation du projet

**Nom :** Mind Race (anciennement Letter Race).

**Concept :** application mobile de rapidité et de réflexion. Une lettre est donnée aux joueurs. Chaque joueur doit trouver le plus rapidement possible un élément correspondant à cette lettre dans différentes catégories.

| Catégorie | Exemple avec « A » |
|-----------|--------------------|
| 🏙️ Ville | Abidjan |
| 🌍 Pays | Argentine |
| 🐘 Animal | Antilope |
| 🍎 Fruit | Ananas |

Le joueur qui trouve des réponses valides dans le temps imparti accumule des points.

## 2. Objectifs du jeu

- rapide à comprendre ;
- amusant ;
- compétitif ;
- adapté aux parties courtes ;
- jouable seul ou à plusieurs ;
- entièrement utilisable sur smartphone et tablette ;
- assez simple pour tous les âges ;
- capable de gérer plusieurs parties simultanément.

Objectif principal : une expérience proche du Petit Bac, pensée dès le départ pour le mobile et le multijoueur temps réel.

## 3. Plateformes

- **Version principale :** Android (Google Play Store)
- **Version future :** iOS (Apple App Store)
- **Interface :** Flutter + Dart (base de code commune Android/iOS)

## 4. Mode Solo

Le joueur joue contre le temps.

```
Lettre : M

Ville     : Marseille
Pays      : Maroc
Animal    : Mouton
Fruit     : Mangue

Temps restant : 12 s
```

À la fin du temps, les réponses sont évaluées. Paramètres : nombre de manches, durée d'une manche, catégories, niveau de difficulté.

## 5. Mode Duel

Deux joueurs s'affrontent.

- Joueur A : « Créer une partie » → le jeu génère un code (ex. `X7K92`).
- Joueur B : « Rejoindre une partie » → saisit `X7K92`.

Les deux joueurs arrivent dans le même salon :

```
┌────────────────────────┐
│       SALON DE JEU     │
│                        │
│ 👤 Joueur 1     ✓      │
│ 👤 Joueur 2     ✓      │
│                        │
│       PRÊTS !          │
└────────────────────────┘
```

Quand les deux sont prêts : 3… 2… 1… GO ! La même lettre est envoyée aux deux joueurs.

## 6. Mode Multijoueur

Plusieurs joueurs dans une même partie (ex. Blaise, Kevin, Arnaud, Serge, David). MVP : **2 à 8 joueurs**, limite augmentable ensuite.

## 7. Création d'une partie

- **Type :** Solo, Duel, Multijoueur
- **Nombre de manches :** 5, 10, 15
- **Durée :** 15, 30, 45, 60 secondes
- **Catégories :** Ville, Pays, Animal, Fruit
  - Plus tard : Prénom, Métier, Objet, Marque, Film, Sport…

## 8. Déroulement d'une manche

```
ATTENTE → JOUEURS PRÊTS → 3… 2… 1… GO ! → GÉNÉRATION DE LA LETTRE
→ LES JOUEURS RÉPONDENT → FIN DU TEMPS → VALIDATION
→ CALCUL DES POINTS → CLASSEMENT → MANCHE SUIVANTE
```

## 9. Génération de la lettre

Le serveur génère la lettre, pour empêcher la triche par modification de l'application. La lettre est identique pour tous les joueurs de la partie.

## 10. Interface de jeu

```
┌────────────────────────────┐
│ Manche 3 / 10       00:18  │
│                            │
│          LETTRE            │
│            M               │
│                            │
│ 🏙️ Ville                   │
│ [____________________]     │
│ 🌍 Pays                    │
│ [____________________]     │
│ 🐘 Animal                  │
│ [____________________]     │
│ 🍎 Fruit                   │
│ [____________________]     │
│                            │
│       TERMINER             │
└────────────────────────────┘
```

## 11. Chronomètre

Le chronomètre est **autoritaire côté serveur** (pour empêcher de modifier l'heure du téléphone). Le serveur connaît `start_time` et `end_time` ; l'application ne fait qu'afficher le temps restant.

## 12. Bouton « Terminer »

Le joueur peut envoyer ses réponses avant la fin du temps. Le serveur enregistre précisément le moment où chaque joueur a terminé (ex. 14,2 s, 18,7 s, temps écoulé).

## 13. Validation des réponses

Le système vérifie que :

1. **la réponse existe** (Animal : Mouton ✅) ;
2. **elle commence par la bonne lettre** (lettre M, « Chat » ❌) ;
3. **elle correspond à la catégorie** (Pays : Marseille ❌) ;
4. **les variantes sont reconnues** : `éléphant`, `Elephant`, `ELEPHANT` sont la même réponse.

Normalisation : majuscules/minuscules, accents, espaces inutiles, caractères particuliers.

## 14. Base de connaissances

Le serveur dispose d'une base de réponses (cities, countries, animals, fruits).

```
Answer
 ├── value
 ├── category
 ├── normalized_value
 ├── first_letter
 └── accepted
```

## 15. Réponses contestables

Ex. : « kiwi » est-il un fruit ? La base doit être suffisamment fiable. Plus tard : validation automatique, dictionnaire, système communautaire, modération, IA. **L'IA n'est pas obligatoire dans le MVP.**

## 16. Système de points

À détailler plus tard. Principe :

- réponse correcte : +10 points ;
- réponse incorrecte : 0 point ;
- bonus possible pour une réponse unique ;
- bonus possible selon la rapidité ;
- réponse identique entre plusieurs joueurs : points différents (ex. « Marseille » donné par 3 joueurs vaut moins que « Mbandaka » donné par 1 seul). La réponse rare est valorisée.

## 17. Classement

À la fin de chaque manche :

```
🏆 CLASSEMENT
1. 👤 Kevin       38 pts
2. 👤 Blaise      32 pts
3. 👤 Arnaud      25 pts
4. 👤 Serge       18 pts
```

À la fin de la partie : podium 🥇🥈🥉 et totaux.

## 18. Gestion des déconnexions

Perte de connexion, fermeture de l'application, retour dans la partie, abandon, arrivée tardive. Ex. : « ⚠️ Kevin s'est déconnecté. » Le serveur conserve temporairement son état.

## 19. Communication temps réel

WebSocket pour transmettre : joueurs connectés, joueur prêt, démarrage, lettre, chronomètre, joueur ayant terminé, fin de manche, résultats, classement, déconnexion.

## 20. Architecture technique

```
                📱 Flutter
                    │  HTTPS / WebSocket
                    ▼
             🚀 FastAPI
                    │
          ┌─────────┴─────────┐
      PostgreSQL            Redis
   (données du jeu)   (temps réel, état des salles, sessions)
```

- Frontend : Flutter / Dart
- Backend : Python / FastAPI
- Base de données : PostgreSQL
- Temps réel / cache : Redis
- Communication : REST API + WebSocket
- Conteneurisation : Docker
- CI/CD (plus tard) : GitHub Actions, Docker, éventuellement Dokploy

## 21. Architecture Flutter

```
lib/
├── core/        (theme, constants, network, utils)
├── features/    (auth, home, game, lobby, leaderboard, profile)
├── animations/  (countdown, victory, score, transitions)
└── main.dart
```

## 22. Architecture FastAPI

```
app/
├── api/           (auth, games, rooms, players, leaderboard)
├── models/
├── schemas/
├── services/      (game_service, scoring_service, validation_service, room_service)
├── websocket/     (game_ws.py)
├── repositories/
├── core/
└── main.py
```

## 23. Base de données

Entités : User, Game, GameRoom, GameRound, Player, Answer, Category, Score, Leaderboard.

```
User
 └── GameRoom
       ├── Players
       └── Rounds
             ├── Answers
             └── Scores
```

## 24. Compte utilisateur

MVP : jeu possible sans compte (mode invité). Ensuite : connexion, inscription, profil, pseudo, avatar, statistiques, historique. Plus tard : Google, Apple, email…

## 25. Profil joueur

Parties jouées, victoires, réponses, meilleur score. Badges : 🔥 série de victoires, ⚡ réponse éclair, 🧠 expert des lettres.

## 26. Classements (plus tard)

Global, entre amis, hebdomadaire, mensuel, local/pays. Non indispensable pour le MVP.

## 27. Amis et invitations (futur)

Ajouter, inviter, défier un ami, voir ses statistiques. Partage d'un code de partie.

## 28. Notifications (plus tard)

« 🔥 Kevin vous défie ! », « 🎮 Votre ami vient de créer une partie. »

## 29. Motion design

Animations : splash screen, logo, boutons, transitions, compte à rebours, apparition de la lettre, chronomètre, validation des réponses, joueur ayant terminé, attribution des points, classement, victoire, défaite, changement de manche, arrivée/départ d'un joueur.

Outils : Lottie pour les animations complexes, animations Flutter / Rive pour les interactions natives.

## 30. Effets sonores

Clic, début de partie, compte à rebours, dernière seconde, validation, erreur, gain de points, victoire. Désactivables : 🔊 sons, 📳 vibrations, 🎵 musique.

## 31. Design UI/UX

Simple, coloré, lisible, rapide, adapté aux petits écrans, utilisable à une main. Lecture immédiate : la lettre → les catégories → le temps → ses réponses.

## 32. Sécurité et anti-triche

Le serveur est la source de vérité : temps, lettre, fin de manche, scores, réponses envoyées, état des joueurs. Le client ne décide jamais seul de son score : le serveur calcule réponses → validation → score.

## 33. MVP

Flutter, Android, mode solo, mode duel, multijoueur, création de salle, code de salle, WebSocket, 4 catégories (Ville, Pays, Animal, Fruit), génération de lettres, chronomètre, validation, système de points, classement, animations principales, PostgreSQL, Redis, FastAPI.

## 34. Version 2

Comptes, profils, statistiques, amis, invitations, classement global, badges, nouvelles catégories, personnalisation des parties, sons plus poussés, système de niveaux.

## 35. Version 3

Tournois, événements, matchmaking, classement compétitif, défis quotidiens, récompenses, mode équipe, événements spéciaux, système social.

## 36. Feuille de route

1. **Fondations** — Flutter, FastAPI, PostgreSQL, Redis, Docker, Git
2. **Jeu solo** — écran principal → choix du mode → lettre → questions → chronomètre → validation → score
3. **Multijoueur** — création de salle → code → connexion joueurs → lobby → ready → WebSocket → jeu
4. **Scoring** — validation → comparaison → points → bonus → classement
5. **Motion design** — countdown, letter reveal, timer, score, leaderboard, victory
6. **Tests** — unitaires, API, WebSocket, Flutter, charge, multijoueur
7. **Production** — Docker → serveur → CI/CD → Google Play Store
