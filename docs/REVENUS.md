# Revenus en plus des pièces — interrupteurs et mise en route

Trois options, **toutes coupées par défaut**. Chacune s'active dans le fichier d'environnement du
serveur (`.env` en local, `backend/.env.production` / variables Dokploy en prod), puis
redémarrage de l'API. L'appli lit les options au démarrage (`GET /api/v1/config` → `features`) et
n'affiche que ce qui est actif : **pas besoin de nouvelle version de l'appli** pour allumer ou
éteindre.

| Interrupteur | Effet |
|---|---|
| `FEATURE_REWARDED_ADS` | Boutique : « Pièces gratuites », une vidéo = `REWARDED_AD_COINS` pièces, `REWARDED_ADS_PER_DAY` fois par jour |
| `FEATURE_INTERSTITIAL_ADS` | Une pub plein écran toutes les `INTERSTITIAL_EVERY_GAMES` parties, en quittant l'écran de fin (jamais pendant une manche) |
| `FEATURE_REMOVE_ADS` | Boutique : achat unique « Sans pub » (produit `remove_ads`) — supprime les pubs entre les parties |
| `FEATURE_SUBSCRIPTION` | Boutique : « Pass » mensuel (produit `pass_monthly`) : sans pub, `PASS_DAILY_COINS` pièces par jour, `PASS_BONUS_HINTS` jokers en plus par partie |

Les vidéos récompensées restent proposées aux joueurs « Sans pub » et Pass (c'est eux qui
choisissent de les regarder).

## Pubs (AdMob)

1. Créer un compte sur [admob.google.com](https://admob.google.com), ajouter l'appli Android et
   iOS, puis deux blocs d'annonces par plateforme : **Avec récompense** et **Interstitiel**.
2. Identifiants d'application (format `ca-app-pub-…~…`) :
   - Android : compiler avec `-PADMOB_APP_ID=ca-app-pub-…~…` (sinon identifiant de test Google) ;
   - iOS : remplacer `GADApplicationIdentifier` dans `mobile/ios/Runner/Info.plist`.
3. Blocs d'annonces (format `ca-app-pub-…/…`), à la compilation :
   ```
   flutter build appbundle \
     --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-…/… \
     --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-…/…
   ```
   (et `ADMOB_REWARDED_IOS`, `ADMOB_INTERSTITIAL_IOS` pour iPhone). Sans ces valeurs, l'appli
   utilise les blocs **de test** de Google : de vraies pubs de démonstration, sans revenu ni
   risque pour le compte.
4. **Vérification côté serveur** (obligatoire en prod) : dans AdMob, bloc « Avec récompense » →
   *Vérification côté serveur* → URL de rappel :
   `https://TON-DOMAINE/api/v1/ads/reward-callback`.
   AdMob appelle cette URL, signée par Google, quand une vidéo est vue en entier ; le serveur
   vérifie la signature et crédite les pièces (une fois par vidéo, dans la limite du jour).
   L'appli ne peut pas tricher.
5. `REWARDED_ADS_TRUST_CLIENT=true` sert **uniquement en local** (les blocs de test ne font pas de
   rappel serveur) : le serveur croit alors l'appli. Toujours `false` en prod.
6. Consentement RGPD : l'appli affiche le formulaire de consentement de Google (UMP) avant toute
   pub. Le configurer dans AdMob → *Confidentialité et messages*.

## « Sans pub » et Pass (Play Console / App Store Connect)

| Identifiant | Type | Prix conseillé |
|---|---|---|
| `remove_ads` | Produit intégré **non consommable** | 2,99 € |
| `pass_monthly` | **Abonnement** mensuel | 2,99 €/mois |

Le serveur vérifie chaque achat auprès du store (mêmes clés que la boutique de pièces, voir
`docs/BOUTIQUE.md`) : « Sans pub » est restauré si le joueur réinstalle l'appli, et la fin du Pass
est redemandée au store quand elle est dépassée (renouvellement automatique pris en compte).

Commissions : 15 % (petits développeurs) sur les achats ; abonnements 15 % chez Google, 30 % la
première année puis 15 % chez Apple. AdMob paie séparément, chaque mois, au-delà d'environ 70 €.
