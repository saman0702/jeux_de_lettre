from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Dans Docker, DATABASE_URL / REDIS_URL sont fournis par docker-compose. En local, les URL sont
    # construites à partir des valeurs POSTGRES_* / REDIS_PORT du .env du dépôt.
    model_config = SettingsConfigDict(env_file=(".env", "../.env"), extra="ignore")

    app_name: str = "Letter Battle API"

    postgres_user: str = "letterbattle"
    postgres_password: str = "letterbattle"
    postgres_db: str = "letterbattle"
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    redis_port: int = 6379

    database_url_env: str | None = Field(default=None, validation_alias="DATABASE_URL")
    redis_url_env: str | None = Field(default=None, validation_alias="REDIS_URL")

    @property
    def database_url(self) -> str:
        return self.database_url_env or (
            f"postgresql+asyncpg://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    @property
    def redis_url(self) -> str:
        return self.redis_url_env or f"redis://localhost:{self.redis_port}/0"


settings = Settings()
