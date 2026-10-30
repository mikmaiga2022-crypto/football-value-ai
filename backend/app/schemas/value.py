"""Schémas Value Betting (Phase 5)."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ValueBetOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    match_id: str
    market_code: str
    selection_code: str
    line: float | None = None
    implied_prob_novig: float
    fair_odds: float
    ev: float
    ev_lower: float
    edge: float
    score: float
    priority: str
    status: str
    created_at: datetime
