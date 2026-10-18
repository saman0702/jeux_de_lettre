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
