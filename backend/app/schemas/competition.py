"""Schémas du catalogue et du plan de couverture."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class CompetitionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    code: str
    name: str
    country_code: str | None
    confederation: str | None
    is_international: bool
    tier: int
    season: str | None
    coverage_state: Literal["served", "opportunistic", "catalog", "disabled"]
    notes: str | None = None


class CoverageEntry(BaseModel):
    code: str
    name: str
    state: Literal["served", "opportunistic", "catalog", "disabled"]
    reason: str


class CoverageQuota(BaseModel):
    provider: str
    used_today: int
    used_month: int
    monthly_budget: int
    monthly_limit: int
    remaining: int
    exhausted: bool
    degraded_reason: str | None


class CoverageResponse(BaseModel):
    served: list[CoverageEntry]
    opportunistic: list[CoverageEntry]
    catalog: list[CoverageEntry]
    disabled: list[CoverageEntry]
    monthly_credits: int
    monthly_budget: int
    headroom: int
    quota: CoverageQuota
    notes: list[str] = Field(default_factory=list)
