# IDs AdMob Android Mind Race — sourcés par les scripts de build release.
# Surcharge possible : ADMOB_APP_ID=… ./scripts/build_playstore_aab.sh
#
# App (~) : une seule pour toute l'appli.
# Blocs (/) : récompense = vidéo boutique ; interstitiel = entre les parties.

: "${ADMOB_APP_ID:=ca-app-pub-9661994862990143~8534933195}"
: "${ADMOB_REWARDED_ANDROID:=ca-app-pub-9661994862990143/2685721041}"
: "${ADMOB_INTERSTITIAL_ANDROID:=ca-app-pub-9661994862990143/1324537915}"
