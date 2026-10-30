"""Schémas des rencontres et des cotes (Phase 3)."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict


class TeamOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    short_name: str | None = None
    country_code: str | None = None
    logo_url: str | None = None


class MatchOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    competition_code: str
    season: str | None = None
    round: str | None = None
    kickoff_utc: datetime
    status: Literal[
        "scheduled", "live", "halftime", "finished", "postponed", "cancelled", "suspended"
    ]
    minute: int | None = None
    home_team: TeamOut
    away_team: TeamOut
    home_score: int | None = None
    away_score: int | None = None
    home_score_ht: int | None = None
    away_score_ht: int | None = None
    data_quality_score: float
    source_id: str
    last_synced_at: datetime | None = None


class OddsSnapshotOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    match_id: str
    bookmaker_code: str
    market_code: str
    selection_code: str
    line: float | None = None
    decimal_odds: float
    is_verified: bool
    is_available: bool
    observed_at: datetime
    source_id: str


class OddsLatestResponse(BaseModel):
    match_id: str
    snapshots: list[OddsSnapshotOut]
