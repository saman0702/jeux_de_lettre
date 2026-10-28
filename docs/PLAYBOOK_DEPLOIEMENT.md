# Playbook — publier Mind Race sur l'App Store et le Play Store

Ce document suit l'ordre à respecter. Chaque étape a sa liste de cases à cocher.

- **iOS** : compilé et envoyé sur TestFlight par **Codemagic** (fichier `codemagic.yaml` à la racine
  du dépôt) : on ne peut pas compiler pour iPhone depuis Linux, Codemagic le fait sur des Mac dans le
  cloud.
- **Android** : compilé ici, à la main, puis envoyé dans la Play Console.

Documents liés : `docs/BOUTIQUE.md` (pièces), `docs/REVENUS.md` (pubs, Sans pub, Pass).

---

## 0. Ce qu'il faut avant de commencer

| Quoi | Coût | Délai |
|---|---|---|
| Compte **Google Play Console** | 25 $ une fois | vérification d'identité : 1 à 3 jours |
| Compte **Apple Developer** | 99 $ par an | 1 à 2 jours (plus si entreprise : numéro D-U-N-S) |
| Compte **AdMob** (Google) | gratuit | quelques heures (validation de l'appli après publication) |
| Compte **Codemagic** | gratuit : 500 min de compilation par mois | immédiat |
| Une **page web de politique de confidentialité** | — | obligatoire pour les deux stores (pubs + vocal + pseudo) |
| Un **site web** du développeur (même simple) | — | pour le fichier `app-ads.txt` d'AdMob |

Identifiants techniques (ne pas les changer, sinon ce sont d'autres applis) :

| | Android | iOS |
|---|---|---|
| Identifiant | `com.letterbattle.letter_battle` | `com.letterbattle.letterBattle` |
| Nom affiché | Mind Race | Mind Race |
| Version | `version:` dans `mobile/pubspec.yaml` (ex. `1.0.0+1`) | idem |

---

## 1. Le serveur de prod d'abord

L'appli publiée parle au serveur `https://gamelr-api.optisoftw.com`. Il doit être à jour **avant**
d'envoyer l'appli aux stores (les relecteurs d'Apple et de Google la testent).

- [ ] Déployer la dernière version du backend (Dokploy). Au démarrage, `alembic upgrade head`
      applique les nouvelles migrations (jeton secret, parties de QI, défi du jour).
- [ ] Vérifier : `https://gamelr-api.optisoftw.com/health` répond `ok`, et
      `/api/v1/iq/puzzles?count=1` renvoie une énigme.
- [ ] Supprimer le joueur de test « Probe » (`client_id = probe-test-1`) de la table `profiles`.
- [ ] Variables d'environnement de prod (Dokploy) — voir la section 5 pour les pubs et la boutique :
      `RATE_LIMIT_PER_MINUTE=240`, `REWARDED_ADS_TRUST_CLIENT=false`.

> Les anciennes versions de l'appli (sans jeton secret) ne peuvent plus se connecter : c'est normal,
> tout le monde aura la version des stores.

---

## 2. Android (Play Console) — à la main

### 2.1 La clé d'envoi (déjà créée)

Elle signe chaque version envoyée au Play Store. **Perdue = impossible de mettre l'appli à jour**
(sauf procédure de récupération Google).

| Fichier | Rôle |
|---|---|
| `secrets/mind-race-upload.jks` | la clé d'envoi (alias `upload`) |
| `secrets/ANDROID_UPLOAD_KEY.txt` | son mot de passe et son empreinte |
| `mobile/android/key.properties` | relie la clé à la compilation (lu par `build.gradle.kts`) |

Ces trois fichiers sont exclus de git.

- [ ] **Sauvegarder** `secrets/mind-race-upload.jks` et son mot de passe hors de ce PC
      (gestionnaire de mots de passe + clé USB ou cloud privé).

Sans `key.properties`, la version release est signée avec la clé de debug : bon pour tester,
refusé par le Play Store.

### 2.2 Compiler la version à envoyer

Depuis `mobile/` :

```bash
ADMOB_APP_ID=ca-app-pub-…~… \
flutter build appbundle --release \
  --build-number=2 \
  --dart-define=API_BASE_URL=https://gamelr-api.optisoftw.com \
  --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-…/… \
  --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-…/…
```

- Le fichier à envoyer : `mobile/build/app/outputs/bundle/release/app-release.aab`.
- `--build-number` : **augmenter de 1 à chaque envoi** (le Play Store refuse un numéro déjà
  utilisé). La version affichée (`1.0.0`) vient de `version:` dans `mobile/pubspec.yaml`.
- Sans les valeurs AdMob (tant que le compte AdMob n'est pas prêt), enlever ces trois réglages :
  l'appli affiche les pubs de test de Google.

### 2.3 Créer l'appli

- [ ] Play Console > *Créer une application* : nom « Mind Race », jeu, gratuit.
- [ ] Laisser **Play App Signing** activé (Google garde la clé finale ; la nôtre ne sert qu'à
      l'envoi).
- [ ] *Fiche du Play Store* : description courte et longue, icône 512 px
      (`mobile/assets/branding/mind_race_icon.png` redimensionnée), image de présentation
      1024 × 500, au moins 2 captures d'écran (dossier `docs/screenshots/`).
- [ ] *Contenu de l'application* :
  - politique de confidentialité (URL) ;
  - **Annonces** : oui ;
  - **Accès à l'appli** : aucun compte nécessaire (joueurs invités) ;
  - **Sécurité des données** : identifiant d'appareil (client_id), pseudo, pays, photo d'avatar
    (facultative), enregistrement audio pendant le vocal (non conservé), identifiant publicitaire
    (AdMob) ; données chiffrées en transit ;
  - **Classification du contenu** : achats intégrés, **jeu d'argent simulé** (salons à mise en
    pièces), interactions entre joueurs (chat, vocal) ;
  - **Public cible** : 13 ans et plus (le chat et le vocal entre inconnus excluent les moins de
    13 ans).

### 2.4 Premier envoi (obligatoire avant de créer les produits)

- [ ] *Tester > Tests internes > Créer une version* : glisser `app-release.aab`, puis
      *Enregistrer* et *Envoyer pour examen* (les tests internes sont disponibles en quelques
      minutes).
- [ ] *Testeurs* : ajouter les adresses Gmail, ouvrir le lien de participation sur ton téléphone,
      installer depuis le Play Store.

---

## 3. Codemagic (iOS seulement)

### 3.1 Brancher le dépôt

- [ ] codemagic.io > *Add application* > choisir le dépôt Git > type **Flutter**.
- [ ] Codemagic lit `codemagic.yaml` : un seul workflow, **`ios-release`**.

### 3.2 Réglages à faire une fois

- [ ] *Team settings > Integrations > Apple Developer Portal* : ajouter la clé API App Store Connect
      (section 4.1) sous le nom **`Mind Race Codemagic`**.
- [ ] Groupe d'environnement **`ios_signing`** (sur l'Application), variable
      `CERTIFICATE_PRIVATE_KEY` (cocher *Secret*) = **contenu** du fichier `secrets/ios_cert_key`
      (déjà créé, clé RSA au format PEM). Codemagic s'en sert pour créer puis réutiliser le
      certificat de distribution et le profil App Store.
- [ ] Groupe **`admob_ios`** (facultatif tant qu'AdMob n'est pas prêt) : `ADMOB_APP_ID_IOS`
      (`ca-app-pub-…~…`), `ADMOB_REWARDED_IOS` et `ADMOB_INTERSTITIAL_IOS` (`ca-app-pub-…/…`),
      cocher *Secret*. Vides : pubs de test de Google.
- [ ] Dans `codemagic.yaml`, remplacer `APP_STORE_APPLE_ID: "0000000000"` par l'Apple ID numérique
      de l'appli (section 4.1).

### 3.3 Lancer une compilation

- **Automatiquement** : chaque push sur `main` (ou `release/…`) qui touche `mobile/` ou
  `codemagic.yaml`, et chaque étiquette Git.
- **À la main** : Codemagic > *Start new build* > `ios-release`.
- `[skip ci]` dans le message de commit : aucune compilation.
- Le numéro de build est calculé tout seul (dernier build TestFlight + 1) ; la version affichée
  vient de `version:` dans `mobile/pubspec.yaml`.
- Un e-mail arrive à la fin (réussite ou échec), avec l'IPA et les journaux en pièces jointes.

---

## 4. iOS (App Store Connect)

### 4.1 Comptes et identifiants

- [ ] developer.apple.com > *Identifiers* : créer l'App ID `com.letterbattle.letterBattle`
      avec la capacité **In-App Purchase** (cochée par défaut).
- [ ] App Store Connect > *Mes apps* > **+** : « Mind Race », identifiant ci-dessus, SKU
      `mindrace`. Noter l'**Apple ID** numérique de l'appli (Infos de l'app) et le mettre dans
      `codemagic.yaml` à la place de `APP_STORE_APPLE_ID: "0000000000"`.
- [ ] *Accords, taxes et banques* : signer l'accord **Applications payantes** (coordonnées
      bancaires et fiscales). Sans lui, les achats intégrés ne marchent pas.
- [ ] *Utilisateurs et accès > Intégrations > App Store Connect API* : créer une clé (rôle
      **App Manager**), télécharger le `.p8`, noter **Issuer ID** et **Key ID**.
- [ ] Codemagic > *Team settings > Integrations > Apple Developer Portal* : ajouter cette clé sous
      le nom **`Mind Race Codemagic`** (section 3.2).

### 4.2 Fiche de l'appli

- [ ] Captures d'écran iPhone 6,7" et 6,5" (obligatoires), icône (envoyée avec la compilation).
- [ ] Politique de confidentialité (URL) et **étiquettes de confidentialité** (« Données utilisées
      pour vous suivre » : identifiant publicitaire si les pubs personnalisées sont actives ;
      « Données liées à vous » : identifiant d'appareil, pseudo, contenu audio pendant le vocal).
- [ ] Classification d'âge : **jeu d'argent simulé : peu fréquent**, contenu généré par les
      utilisateurs (chat, vocal) ⇒ 12+ ou 17+ selon les réponses.
- [ ] Notes pour la relecture d'Apple : « Pas de compte nécessaire. Les pièces s'achètent ou se
      gagnent en jouant, n'ont aucune valeur monétaire et ne se retirent pas. Le chat et le vocal
      proposent de signaler un joueur. »

### 4.3 Envoi sur TestFlight

- [ ] Lancer le workflow **ios-release** : l'IPA est envoyée sur App Store Connect, puis apparaît
      dans **TestFlight** après le traitement d'Apple (10 à 30 min).
- [ ] App Store Connect > *TestFlight* : ajouter les testeurs (ton compte Apple en premier).
- [ ] Installer l'appli TestFlight sur l'iPhone, tester la partie, le QI, les pubs de test et la
      boutique avec un compte **Sandbox** (section 5.2).
- [ ] *App Store > Préparer la soumission* : choisir le build, envoyer à la relecture
      (24 à 48 h en général).

---



========================BOUTIQUE ET PUB===================================



## 5. Pubs et boutique

Tout se règle **sur le serveur** (variables d'environnement Dokploy), sauf les identifiants AdMob
qui vont dans Codemagic. L'appli lit les options au démarrage : pas besoin de nouvelle version
pour allumer ou couper une option.

### 5.1 Pubs (AdMob)

- [ ] admob.google.com > *Applications* > ajouter **Mind Race Android** et **Mind Race iOS**
      (d'abord « pas encore publiée », à relier au store après publication).
- [ ] Pour chaque plateforme, créer deux blocs d'annonces : **Avec récompense** et
      **Interstitiel**. Identifiants iOS : groupe Codemagic `admob_ios` (section 3.2) ;
      identifiants Android : dans la commande de compilation (section 2.2).
- [ ] Bloc « Avec récompense » > **Vérification côté serveur** > URL de rappel :
      `https://gamelr-api.optisoftw.com/api/v1/ads/reward-callback`
      (le serveur vérifie la signature de Google avant de créditer les pièces).
- [ ] *Confidentialité et messages* : créer le message de **consentement RGPD** (Europe) et, pour
      iOS, le message **ATT** (suivi publicitaire). L'appli affiche le formulaire de Google avant
      toute pub.
- [ ] Mettre le fichier **`app-ads.txt`** donné par AdMob à la racine du site du développeur, et
      renseigner ce site dans les deux fiches de store.
- [ ] Serveur, pour allumer :
      ```
      FEATURE_REWARDED_ADS=true        # « Pièces gratuites » (vidéo = REWARDED_AD_COINS pièces)
      REWARDED_AD_COINS=5
      REWARDED_ADS_PER_DAY=10
      FEATURE_INTERSTITIAL_ADS=true    # une pub plein écran toutes les N parties
      INTERSTITIAL_EVERY_GAMES=3
      REWARDED_ADS_TRUST_CLIENT=false  # toujours false en prod
      ```

> Conseil : publier d'abord **sans** l'interstitiel (`FEATURE_INTERSTITIAL_ADS=false`) et avec les
> vidéos récompensées seulement : les joueurs choisissent de les regarder, ça passe mieux à la
> relecture et dans les avis.

### 5.2 Boutique de pièces (achats intégrés)

Produits à créer **avec ces identifiants exacts** dans les deux stores :

| Identifiant | Type | Contenu | Prix conseillé |
|---|---|---|---|
| `coins_100` | consommable | 100 pièces | 0,99 € |
| `coins_550` | consommable | 550 pièces | 4,99 € |
| `coins_1200` | consommable | 1 200 pièces | 9,99 € |
| `coins_2500` | consommable | 2 500 pièces | 19,99 € |
| `remove_ads` | non consommable | Sans pub | 2,99 € |
| `pass_monthly` | abonnement mensuel | Pass Mind Race | 2,99 €/mois |

**Google Play**
- [ ] Après le premier envoi (section 2.3) : *Monétiser > Produits intégrés* : créer les
      4 packs et `remove_ads` ; *Abonnements* : créer `pass_monthly`. Les activer.
- [ ] Google Cloud : créer un **compte de service**, activer l'« API Google Play Android
      Developer », télécharger la clé JSON (la même que pour Codemagic peut servir).
- [ ] Play Console > *Utilisateurs et autorisations* : inviter l'adresse du compte de service
      (droits « Afficher les données financières » et « Gérer les commandes »).
- [ ] *Configuration > Test de licence* : ajouter les Gmail des testeurs (achats non facturés).

**App Store**
- [ ] App Store Connect > l'appli > *Achats intégrés* : les 4 packs (consommables) et
      `remove_ads` (non consommable) ; *Abonnements* : groupe « Pass », produit `pass_monthly`.
      Chaque produit a besoin d'un nom, d'une description et d'une capture d'écran pour la relecture.
- [ ] *Intégrations > Achat intégré* : générer une clé, noter **Key ID** et **Issuer ID**,
      télécharger le `.p8` (une seule fois possible).
- [ ] *Utilisateurs et accès > Testeurs Sandbox* : créer un compte de test.

**Serveur** (fichiers dans `secrets/`, jamais dans git)
```
GOOGLE_SERVICE_ACCOUNT_FILE=secrets/google-service-account.json
APPLE_ISSUER_ID=…
APPLE_KEY_ID=…
APPLE_PRIVATE_KEY_FILE=secrets/apple-iap.p8
APPLE_ENVIRONMENT=sandbox          # « production » une fois l'appli publiée
FEATURE_REMOVE_ADS=true
FEATURE_SUBSCRIPTION=true
PASS_DAILY_COINS=20
PASS_BONUS_HINTS=2
```
- [ ] Redémarrer l'API, ouvrir la boutique dans l'appli de test : les prix viennent du store.
- [ ] Faire un achat de test sur chaque plateforme et vérifier que les pièces arrivent.

---

## 6. Ordre de lancement conseillé

1. Serveur de prod à jour (section 1).
2. Android : clé d'envoi, appli créée, premier envoi en tests internes (section 2).
3. Produits Play créés, achats de test OK (section 5.2).
4. iOS : App Store Connect, clé API dans Codemagic, envoi TestFlight (section 4).
5. Produits App Store créés, achats Sandbox OK (section 5.2).
6. AdMob : applis et blocs créés ; identifiants iOS dans Codemagic, identifiants Android dans la
   commande de compilation ; nouvelles compilations (sections 2.2, 3.2 et 5.1).
7. Tests sur de vrais téléphones (TestFlight + tests internes) : partie, QI, salons, vocal, pubs,
   boutique.
8. Envoi en relecture : Play (*Production* ou *Test fermé* d'abord) et App Store.
9. Après la publication : relier les applis AdMob aux stores, passer `APPLE_ENVIRONMENT=production`.

## 7. Liste finale avant d'envoyer en relecture

- [ ] `API_BASE_URL` pointe sur la prod (pas `10.0.2.2` ni une adresse locale).
- [ ] Les variables AdMob sont les **vraies** (sinon pubs de test).
- [ ] La version release Android est signée avec la clé d'envoi (pas la clé de debug).
- [ ] Politique de confidentialité en ligne et renseignée dans les deux fiches.
- [ ] Classification d'âge : achats intégrés + jeu d'argent simulé déclarés.
- [ ] Les pièces sont présentées comme sans valeur monétaire (déjà affiché dans la boutique).
- [ ] Un relecteur peut jouer sans compte (joueur invité) : c'est déjà le cas.
