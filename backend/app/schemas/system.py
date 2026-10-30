"""Schémas des routes de méta-information."""

from __future__ import annotations

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str
    database: str
    environment: str
    api_version: str
    uptime_seconds: int


class FeatureFlags(BaseModel):
    value_betting: bool = True
    live: bool = False
    manual_odds: bool = True
    simulation: bool = False
    notifications: bool = False


class AppConfigResponse(BaseModel):
    min_app_version: str
    latest_app_version: str
    maintenance: bool = False
    features: FeatureFlags
    legal: dict[str, str] = Field(default_factory=dict)
    data_mode: str = Field(description="`zero_budget` ou `standard`")


class DisclaimerResponse(BaseModel):
    version: str
    updated_at: str
    text: str
