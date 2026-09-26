from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+asyncpg://mytravelpal:mytravelpal@localhost:5432/mytravelpal"
    # Optional. If unset, the plan-cache layer falls back silently to
    # an in-process cachetools.TTLCache — no infra dependency required.
    # Env var `REDIS_URL` overrides this at runtime (pydantic-settings
    # matches case-insensitively).
    redis_url: str | None = None
    log_level: str = "INFO"


settings = Settings()
