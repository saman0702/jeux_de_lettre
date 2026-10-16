# Boutique de pièces — mise en route

Les joueurs achètent des packs de pièces avec le moyen de paiement de leur store (carte, PayPal,
carte cadeau, facturation opérateur…). Le store encaisse, garde sa commission (15 % jusqu'à 1 M$ de
ventes par an) et reverse le reste chaque mois.

Les pièces **ne ressortent jamais en argent** (décision n°48) : pas de retrait, pas de transfert
entre joueurs.

## Comment ça marche

1. L'appli affiche les packs ; les prix viennent du store, dans la monnaie du joueur.
2. Le joueur paie dans la fenêtre Google Play / App Store.
3. L'appli envoie le jeton d'achat au serveur (`POST /api/v1/shop/purchases`).
4. Le serveur **redemande l'achat au store** (API Google Play Developer / App Store Server API),
   puis crédite les pièces une seule fois (le jeton est unique en base, table `coin_purchases`) et
   note le mouvement dans `coin_transactions` (raison `purchase`).
5. L'appli clôt l'achat (« consommation » sur Android) seulement après le crédit. Si le réseau
   coupe entre-temps, l'achat est repris au lancement suivant.

Tant que les stores ne sont pas configurés, la boutique affiche « pas disponible » et le serveur
répond `store_not_configured`.

## Les packs

Identifiants à créer **à l'identique** dans les deux stores (produits « consommables ») :

| Identifiant | Pièces | Prix conseillé | Bonus affiché |
|-------------|--------|----------------|---------------|
| `coins_100` | 100 | 0,99 € | — |
| `coins_550` | 550 | 4,99 € | +10 % |
| `coins_1200` | 1 200 | 9,99 € | +20 % |
| `coins_2500` | 2 500 | 19,99 € | +25 % |

Le nombre de pièces est fixé par le serveur (`COIN_PACKS` dans `backend/app/core/game_rules.py`) ;
un pack absent du store n'est simplement pas affiché. Les stores convertissent les prix par pays
(on peut aussi les ajuster pays par pays).

## Google Play

1. Créer le compte développeur (25 $ une fois) et l'appli `com.letterbattle.letter_battle`.
2. Envoyer un premier APK/AAB sur la piste **Tests internes** (la permission de facturation est
   ajoutée automatiquement par le module `in_app_purchase`) : les produits ne sont visibles
   qu'après ça.
3. *Monétiser > Produits > Produits intégrés à l'application* : créer les 4 produits ci-dessus et
   les activer.
4. Google Cloud : créer un **compte de service**, activer l'« API Google Play Android Developer »,
   télécharger sa clé JSON.
5. Play Console > *Utilisateurs et autorisations* : inviter l'adresse du compte de service avec les
   droits « Afficher les données financières » et « Gérer les commandes ».
6. Copier la clé dans `secrets/google-service-account.json` et mettre dans `.env` :
   `GOOGLE_SERVICE_ACCOUNT_FILE=secrets/google-service-account.json`
7. *Configuration > Test de licence* : ajouter les comptes Gmail des testeurs (achats de test non
   facturés).

## App Store

1. Compte Apple Developer (99 $/an), appli `com.letterbattle.letterBattle`, contrat « Applications
   payantes » signé (coordonnées bancaires et fiscales).
2. App Store Connect > l'appli > *Achats intégrés* : créer les 4 produits « Consommables ».
3. *Utilisateurs et accès > Intégrations > Achat intégré* : générer une clé, noter son **Key ID** et
   l'**Issuer ID**, télécharger le fichier `.p8` (une seule fois possible).
4. Copier la clé dans `secrets/apple-iap.p8` et mettre dans `.env` :
   ```
   APPLE_ISSUER_ID=…
   APPLE_KEY_ID=…
   APPLE_PRIVATE_KEY_FILE=secrets/apple-iap.p8
   APPLE_ENVIRONMENT=sandbox   # « production » une fois l'appli publiée
   ```
5. Dans Xcode : *Signing & Capabilities > + In-App Purchase*. Tester avec un compte « Sandbox ».

Relancer ensuite l'API : `docker compose up -d api`.

## Avant la publication

- Conditions d'utilisation : « Les pièces n'ont aucune valeur monétaire, ne sont ni remboursables,
  ni échangeables, ni convertibles en argent » (déjà affiché dans la boutique).
- Questionnaires de classification d'âge : déclarer les achats intégrés et le **jeu d'argent
  simulé** (salons de paris).
- À faire plus tard : retirer les pièces d'un achat remboursé (notifications Google « Real-time
  developer notifications » / Apple « App Store Server Notifications »).
