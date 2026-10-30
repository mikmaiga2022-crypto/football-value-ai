"""Schémas de simulation (Phase 7)."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class BankrollOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    currency: str
    initial_capital: float
    current_capital: float
    kelly_fraction: float
    is_active: bool


class SimulatedBetOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    bankroll_id: str
    value_bet_id: str
    stake: float
    odds_taken: float
    status: str
    payout: float | None = None
    profit_loss: float | None = None
    placed_at: datetime
    settled_at: datetime | None = None
