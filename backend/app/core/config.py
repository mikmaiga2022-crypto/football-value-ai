"""Configuration applicative.

Toutes les valeurs sont surchargeables par variables d'environnement préfixées `FVA_`
(ex. `FVA_JWT_SECRET`). Le fichier `.env` du dossier `backend/` est lu s'il existe.

Aucune clé de fournisseur de données n'est exposée par l'API : elles vivent uniquement
côté workers (voir docs/02 §9).
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parents[2]

Environment = Literal["dev", "test", "staging", "prod"]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_prefix="FVA_",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # --- Identité -----------------------------------------------------------
    environment: Environment = "dev"
    api_version: str = "1.0.0"
    app_name: str = "FOOTBALL VALUE AI"
    api_prefix: str = "/v1"
    log_level: str = "INFO"

    # --- Base de données ----------------------------------------------------
    database_url: str = "postgresql+asyncpg://fva:fva@localhost:5432/fva"
    db_echo: bool = False
    db_pool_size: int = 5
    db_max_overflow: int = 5

    # --- Redis / files ------------------------------------------------------
    redis_url: str = "redis://localhost:6379/0"
    celery_broker_url: str = "redis://localhost:6379/1"
    celery_result_backend: str = "redis://localhost:6379/2"

    # --- Authentification ---------------------------------------------------
    jwt_secret: str = "dev-secret-change-me-please-32-bytes-min"  # noqa: S105 (dev uniquement)
    jwt_algorithm: str = "HS256"
    jwt_issuer: str = "football-value-ai"
    access_token_ttl_seconds: int = 15 * 60
    refresh_token_ttl_days: int = 30
    password_min_length: int = 10
    max_login_attempts: int = 5
    # Verrouillage progressif après 5 échecs (docs/04 §2).
    lockout_seconds: tuple[int, ...] = (60, 300, 900)

    # --- Quotas fournisseurs (docs/09 §3.3) --------------------------------
    odds_monthly_credit_budget: int = 270
    odds_provider_hard_limit: int = 500
    odds_batch_per_competition_day: int = 3
    coverage_served_slots: int = 3
    coverage_opportunistic_slots: int = 2

    # --- Fournisseurs (Phase 3) ---------------------------------------------
    odds_api_key: str = ""
    odds_api_base_url: str = "https://api.the-odds-api.com/v4"
    odds_api_regions: str = "eu"
    odds_api_markets: str = "h2h,totals"
    odds_api_sport_keys: dict[str, str] = {
        "FR1": "soccer_france_ligue_one",
        "EPL": "soccer_epl",
        "CAN": "soccer_africa_cup_of_nations",
    }
    api_football_key: str = ""
    api_football_base_url: str = "https://v3.football.api-sports.io"
    api_football_league_ids: dict[str, int] = {"FR1": 61, "EPL": 39, "CAN": 6}
    provider_timeout_seconds: int = 10
    provider_max_retries: int = 3

    # --- Divers -------------------------------------------------------------
    cors_origins: list[str] = Field(default_factory=list)
    request_timeout_seconds: int = 10
    docs_enabled: bool = True

    @field_validator("lockout_seconds", mode="before")
    @classmethod
    def _parse_lockout(cls, value: object) -> object:
        if isinstance(value, str):
            return tuple(int(part) for part in value.split(",") if part.strip())
        return value

    @field_validator("cors_origins", mode="before")
    @classmethod
    def _parse_origins(cls, value: object) -> object:
        if isinstance(value, str):
            return [part.strip() for part in value.split(",") if part.strip()]
        return value

    @model_validator(mode="after")
    def _guard_production(self) -> Settings:
        if self.environment in ("staging", "prod"):
            if len(self.jwt_secret) < 32 or "change-me" in self.jwt_secret:
                raise ValueError("FVA_JWT_SECRET doit être défini (>= 32 caractères) hors dev/test")
            if self.docs_enabled:
                raise ValueError("FVA_DOCS_ENABLED doit être false en staging/prod")
        return self

    @property
    def is_production(self) -> bool:
        return self.environment in ("staging", "prod")

    @property
    def server_url(self) -> str:
        return f"https://api.footballvalue.ai{self.api_prefix}"


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()

# Support des variables standard (Render/Heroku) en complément de FVA_*.
import os as _os

_database_url = _os.environ.get("DATABASE_URL")
if _database_url and "FVA_DATABASE_URL" not in _os.environ:
    settings.database_url = _database_url.replace(
        "postgres://", "postgresql+asyncpg://", 1
    ).replace("postgresql://", "postgresql+asyncpg://", 1)

_redis_url = _os.environ.get("REDIS_URL")
if _redis_url and "FVA_REDIS_URL" not in _os.environ:
    settings.redis_url = _redis_url
    settings.celery_broker_url = _redis_url
    settings.celery_result_backend = _redis_url

