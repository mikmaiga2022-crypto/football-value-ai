"""Schémas des prédictions (Phase 4)."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class PredictionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    match_id: str
    model_version_id: str
    market_code: str
    selection_code: str
    line: float | None = None
    probability: float
    ci_low: float
    ci_high: float
    data_quality_score: float
    created_at: datetime


class ComputePredictionsResponse(BaseModel):
    predictions_created: int
