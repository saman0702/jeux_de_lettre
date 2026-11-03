# Étapes Google — AdMob, boutique, mise en production Play Console

Ordre à suivre **pour Android seulement**. Quand tout ça est vert, on passe à
**App Store Connect** (iOS) dans un second temps.

Documents liés : `docs/PLAYBOOK_DEPLOIEMENT.md`, `docs/BOUTIQUE.md`, `docs/REVENUS.md`.

Identifiants Mind Race :

| | Valeur |
|---|---|
| Package Android | `com.letterbattle.letterBattle` |
| Nom affiché | Mind Race |
| API prod | `https://gamelr-api.optisoftw.com` |
| Version | `version:` dans `mobile/pubspec.yaml` (ex. `1.0.0+1`) |

---

## Étape 0 — Prérequis (une fois)

| Quoi | Coût | Notes |
|---|---|---|
| Compte **Google Play Console** | 25 $ une fois | Validation d'identité : 1 à 3 jours |
| Compte **AdMob** (même compte Google ou lié) | gratuit | Créable tout de suite |
| Projet **Google Cloud** | gratuit | Pour le compte de service boutique |
| Page **politique de confidentialité** (URL publique) | — | Obligatoire Play + AdMob |
| Site / domaine développeur | — | Pour `app-ads.txt` |

- [ ] Compte Play Console validé
- [ ] Compte AdMob créé sur [admob.google.com](https://admob.google.com)
- [ ] URL de politique de confidentialité en ligne
- [ ] Sauvegarde hors PC de `secrets/mind-race-upload.jks` + mot de passe
      (`secrets/ANDROID_UPLOAD_KEY.txt`)

---

## Étape 1 — Serveur de prod à jour

L'appli des stores parle à la prod. Les relecteurs Google la testent vraiment.

- [ ] Déployer le backend (Dokploy) ; au démarrage : `alembic upgrade head`
- [ ] Vérifier `https://gamelr-api.optisoftw.com/health` → `ok`
- [ ] Vérifier `https://gamelr-api.optisoftw.com/api/v1/iq/puzzles?count=1`
- [ ] Pubs / boutique encore **coupées** sur le serveur :
  ```
  FEATURE_REWARDED_ADS=false
  FEATURE_INTERSTITIAL_ADS=false
  FEATURE_REMOVE_ADS=false
  FEATURE_SUBSCRIPTION=false
  REWARDED_ADS_TRUST_CLIENT=false
  ```

---

## Étape 2 — Créer l'appli dans Play Console

- [ ] Play Console → **Créer une application**
  - Nom : **Mind Race**
  - Type : **Jeu**
  - Gratuit
- [ ] Laisser **Play App Signing** activé (Google garde la clé finale)
- [ ] **Fiche du Play Store**
  - Description courte + longue
  - Icône 512 × 512 (`mobile/assets/branding/mind_race_icon.png`)
  - Image de présentation 1024 × 500
  - Au moins 2 captures d'écran (`docs/screenshots/`)
  - Catégorie : Jeux
  - Coordonnées développeur + URL politique de confidentialité
- [ ] **Contenu de l'application**
  - Annonces : **Oui**
  - Accès : aucun compte obligatoire (joueur invité)
  - Sécurité des données : `client_id`, pseudo, pays, avatar (opt.), audio vocal
    (non conservé), identifiant pub AdMob ; transit chiffré
  - Classification : achats intégrés, **jeu d'argent simulé** (salons à mise),
    interactions (chat / vocal)
  - Public cible : **13 ans et plus**

---

## Étape 3 — Premier build Android signé (tests internes)

Sans ce premier AAB, **les produits boutique n'apparaissent pas**.

Depuis `mobile/` (sans AdMob réel tant que les blocs ne sont pas prêts → pubs de test Google) :

```bash
flutter build appbundle --release \
  --build-number=1 \
  --dart-define=API_BASE_URL=https://gamelr-api.optisoftw.com
```

Fichier : `mobile/build/app/outputs/bundle/release/app-release.aab`.

- [ ] `mobile/android/key.properties` présent (sinon signature debug → refus Play)
- [ ] Play Console → **Tester → Tests internes → Créer une version**
- [ ] Déposer l'AAB → Enregistrer → Envoyer pour examen
- [ ] Ajouter tes Gmail en testeurs → installer via le lien Play

> À chaque nouvel envoi : **augmenter** `--build-number` (1, 2, 3…).

---

## Étape 4 — AdMob (pubs Google)

### 4.1 Appli + blocs

- [ ] AdMob → **Applications** → Ajouter **Mind Race** (Android)
  - D'abord « pas encore publiée » ; on la reliera au Play Store après la prod
- [ ] Créer 2 blocs d'annonces Android :
  | Type | Usage dans Mind Race |
  |---|---|
  | **Avec récompense** | « Pièces gratuites » (vidéo) |
  | **Interstitiel** | Pub plein écran toutes les N parties (fin de partie) |
- [ ] Noter :
  - App ID : `ca-app-pub-….~…`
  - Rewarded unit : `ca-app-pub-…/…`
  - Interstitial unit : `ca-app-pub-…/…`

### 4.2 Rappel serveur (anti-triche)

- [ ] Bloc **Avec récompense** → **Vérification côté serveur**
- [ ] URL de rappel :
  ```
  https://gamelr-api.optisoftw.com/api/v1/ads/reward-callback
  ```
- [ ] AdMob signe l'appel ; le serveur crédite **une seule fois** par vidéo

### 4.3 Consentement + app-ads.txt

- [ ] AdMob → **Confidentialité et messages**
  - Message **consentement RGPD** (Europe)
- [ ] Placer le fichier **`app-ads.txt`** (fourni par AdMob) à la **racine** du site
      développeur
- [ ] Mettre l'URL de ce site dans la fiche Play Store

### 4.4 Rebuild avec les vrais IDs

Les IDs sont dans `mobile/scripts/admob_defaults.sh` (app `…~8534933195`,
récompense `…/2685721041`, interstitiel `…/1324537915`).

```bash
cd mobile
./scripts/build_playstore_aab.sh
```

- [ ] Nouvel AAB envoyé en **tests internes**
- [ ] Features serveur `true` + ce build → pubs du compte AdMob (pas les démos Google)

### 4.5 Allumer pubs + Premium sur le serveur (modèle actuel)

Pubs plein écran **et** abonnement anti-pub **en même temps** :

```
FEATURE_REWARDED_ADS=false
FEATURE_INTERSTITIAL_ADS=true
INTERSTITIAL_EVERY_GAMES=3
FEATURE_REMOVE_ADS=false
FEATURE_SUBSCRIPTION=true
PASS_DAILY_COINS=0
PASS_BONUS_HINTS=0
REWARDED_ADS_TRUST_CLIENT=false   # toujours false en prod
```

Build AAB : les IDs AdMob sont déjà dans `mobile/scripts/admob_defaults.sh`
(pas besoin de les retaper). Surcharge possible via l'env si tu changes de compte.

```
./scripts/build_playstore_aab.sh
# ou : SKIP_CLEAN=1 ./scripts/build_playstore_aab.sh
```

- [ ] Redémarrer l'API
- [ ] Finir une partie → quitter l'écran de fin → pub interstitielle
- [ ] Premium : bouton d'abonnement visible (achat seulement via build Play)

---

## Étape 5 — Boutique (achats Google Play)

### 5.1 Produits à créer (identifiants exacts)

| Identifiant | Type | Contenu | Prix conseillé |
|---|---|---|---|
| `pass_monthly` | Abonnement mensuel | **Premium** : aucune pub 1 mois | 2,99 € / mois |
| `coins_100` | Consommable | 100 pièces *(optionnel)* | 0,99 € |
| `coins_550` | Consommable | 550 pièces *(optionnel)* | 4,99 € |
| `coins_1200` | Consommable | 1 200 pièces *(optionnel)* | 9,99 € |
| `coins_2500` | Consommable | 2 500 pièces *(optionnel)* | 19,99 € |
| `remove_ads` | Non consommable | Sans pub à vie *(optionnel, off)* | 2,99 € |

- [ ] **Monétiser → Abonnements**
  - Créer `pass_monthly` → **Activer** (obligatoire pour Premium)
- [ ] Play Console → **Monétiser → Produits → Produits intégrés**
  - Packs pièces seulement si tu les veux encore ; `remove_ads` laisser inactif si `FEATURE_REMOVE_ADS=false`

### 5.2 Compte de service (vérif serveur)

- [ ] Google Cloud → créer un **compte de service**
- [ ] Activer l'API **Google Play Android Developer**
- [ ] Télécharger la clé JSON → `secrets/google-service-account.json` (hors git)
- [ ] Play Console → **Utilisateurs et autorisations**
  - Inviter l'e-mail du compte de service
  - Droits : **Afficher les données financières** + **Gérer les commandes**
- [ ] Play Console → **Configuration → Test de licence**
  - Ajouter les Gmail des testeurs (achats **non facturés**)

### 5.3 Variables serveur boutique

```
GOOGLE_SERVICE_ACCOUNT_FILE=secrets/google-service-account.json
FEATURE_SUBSCRIPTION=true
FEATURE_REMOVE_ADS=false
PASS_DAILY_COINS=0
PASS_BONUS_HINTS=0
```

- [ ] Redémarrer l'API
- [ ] Sur un téléphone **testeur licence** (AAB installé depuis Play, pas `flutter run`) :
      Boutique → **Premium** → prix Play Store → achat test
- [ ] Après achat : plus de pub interstitielle jusqu'à `pass_expires_at`
- [ ] Packs pièces : optionnel

---

## Étape 6 — Mise en production Play Console

### 6.1 Checklist avant relecture

- [ ] `API_BASE_URL` = prod (pas d'IP locale)
- [ ] AAB signé avec la **clé d'envoi** (`mind-race-upload.jks`)
- [ ] IDs AdMob **réels** dans le build (sinon pubs de test)
- [ ] `REWARDED_ADS_TRUST_CLIENT=false`
- [ ] Politique de confidentialité renseignée
- [ ] Classification : achats + jeu d'argent simulé déclarés
- [ ] Pièces présentées **sans valeur monétaire** (déjà dans l'UI boutique)
- [ ] Un relecteur peut jouer **sans compte**

### 6.2 Envoi production

- [ ] Compiler l'AAB final (`--build-number` neuf)
- [ ] Play Console → **Production** (ou **Test fermé** d'abord, recommandé)
  - Créer une version → déposer l'AAB
  - Notes de version
  - Envoyer pour examen
- [ ] Délai typique : quelques heures à ~7 jours
- [ ] Après validation : **Publier** (ou publication automatique si choisie)

### 6.3 Après la mise en ligne

- [ ] AdMob → relier l'appli Android au **listing Play Store**
- [ ] Vérifier qu'un vrai appareil (hors testeurs) installe depuis le Play Store
- [ ] Surveiller plantages : Play Console → **Android Vitals**
- [ ] (Optionnel) Allumer `FEATURE_INTERSTITIAL_ADS=true` si les avis / rétention vont bien

---

## Ordre résumé (Google seulement)

```
0. Comptes Play + AdMob + politique de confidentialité
1. Serveur prod OK (features pubs/boutique off)
2. Créer l'appli Play Console + fiche
3. Premier AAB → Tests internes
4. AdMob (blocs, callback, RGPD, app-ads.txt) → rebuild
5. Produits boutique + compte de service → achats test
6. Allumer rewarded (puis éventuellement interstitiel) sur le serveur
7. AAB final → Production / Test fermé → Publication
8. Relier AdMob au store
```

---

## Ensuite → App Store Connect

Quand Android est en test interne (idéalement) ou en prod :

1. Compte Apple Developer (99 $/an)
2. App ID `com.letterbattle.letterBattle` + In-App Purchase
3. App Store Connect : créer Mind Race, accords payants, produits boutique
4. Clé API → Codemagic (`ios-release`)
5. AdMob iOS + groupe Codemagic `admob_ios`
6. TestFlight → relecture App Store
7. `APPLE_ENVIRONMENT=production` après publication

Détail iOS : sections 3 et 4 de `docs/PLAYBOOK_DEPLOIEMENT.md` — on les déroule
**après** cette checklist Google.
