from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Prod : backend/.env.production (ou variables injectées au `docker run`).
    # Local : .env du dépôt / backend/.env.
    model_config = SettingsConfigDict(
        env_file=(".env.production", ".env", "../.env"),
        extra="ignore",
    )

    app_name: str = "Letter Race API"
    # Requêtes API par minute et par adresse IP (0 = pas de limite).
    rate_limit_per_minute: int = 240

    postgres_user: str = "letterbattle"
    postgres_password: str = "letterbattle"
    postgres_db: str = "letterbattle"
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    redis_port: int = 6379
    # Avatars dessinés à partir des photos (servis sous /media).
    media_dir: str = "media"

    # Boutique : vérification des achats auprès des stores. Sans ces réglages, la boutique répond
    # « store_not_configured ».
    google_play_package: str = "com.letterbattle.letter_battle"
    # Fichier JSON du compte de service ayant accès à l'API Google Play Developer.
    google_service_account_file: str | None = None
    apple_bundle_id: str = "com.letterbattle.letterBattle"
    apple_issuer_id: str | None = None
    apple_key_id: str | None = None
    # Clé privée « In-App Purchase » (.p8) téléchargée depuis App Store Connect.
    apple_private_key_file: str | None = None
    # « sandbox » pendant les tests, « production » une fois l'appli publiée.
    apple_environment: str = "sandbox"

    # Revenus en plus de la vente de pièces : chaque option s'active ou se coupe ici (le serveur
    # les transmet à l'appli au démarrage, sans nouvelle version de l'appli).
    # Pubs récompensées : une vidéo regardée = des pièces, avec une limite par jour.
    feature_rewarded_ads: bool = False
    rewarded_ad_coins: int = 5
    rewarded_ads_per_day: int = 10
    # Seulement pour les tests en local : crédite la récompense signalée par l'appli. En prod,
    # laisser à false : AdMob prévient le serveur lui-même (vérification côté serveur, signée).
    rewarded_ads_trust_client: bool = False
    # Pub plein écran entre les parties, toutes les N parties terminées.
    feature_interstitial_ads: bool = False
    interstitial_every_games: int = 3
    # Achat unique « Sans pub » (produit non consommable `remove_ads`).
    feature_remove_ads: bool = False
    # Abonnement « Pass » (produit `pass_monthly`) : sans pub, bonus de pièces chaque jour,
    # jokers en plus dans chaque partie.
    feature_subscription: bool = False
    pass_daily_coins: int = 20
    pass_bonus_hints: int = 2

    # Vocal pendant la partie (Agora). Vide = vocal désactivé.
    agora_app_id: str | None = Field(default=None, validation_alias="AGORA_APP_ID")
    agora_app_certificate: str | None = Field(
        default=None, validation_alias="AGORA_APP_CERTIFICATE"
    )

    database_url_env: str | None = Field(default=None, validation_alias="DATABASE_URL")
    redis_url_env: str | None = Field(default=None, validation_alias="REDIS_URL")

    @property
    def database_url(self) -> str:
        if self.database_url_env:
            url = self.database_url_env
            # Docker / hébergeurs donnent souvent postgresql:// ; SQLAlchemy async
            # attend le driver asyncpg.
            if url.startswith("postgresql://"):
                return "postgresql+asyncpg://" + url.removeprefix("postgresql://")
            return url
        return (
            f"postgresql+asyncpg://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    @property
    def redis_url(self) -> str:
        return self.redis_url_env or f"redis://localhost:{self.redis_port}/0"


settings = Settings()
