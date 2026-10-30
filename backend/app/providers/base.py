"""Contrats des fournisseurs de données (Phase 3 — non implémentés en Phase 2).

Une seule interface, pour remplacer une source sans toucher au domaine (docs/02 §3).
Aucune implémentation ne doit exister sans clé API et validation de licence.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass, field
from datetime import datetime
from typing import Protocol


@dataclass(frozen=True)
class RawOdd:
    """Une cote brute, telle que reçue, avec sa provenance complète."""

    source: str
    source_event_id: str
    bookmaker: str
    market: str
    selection: str
    decimal_odds: float
    observed_at: datetime
    raw_payload_hash: str
    line: float | None = None
    is_verified: bool = False
    competition_code: str | None = None
    home_team: str | None = None
    away_team: str | None = None
    kickoff_utc: datetime | None = None
    metadata: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class ProviderHealth:
    name: str
    healthy: bool
    latency_ms: int | None = None
    credits_remaining: int | None = None
    message: str | None = None


class OddsProvider(Protocol):
    name: str

    async def fetch_odds(
        self, competition_codes: Sequence[str], markets: Sequence[str]
    ) -> list[RawOdd]: ...

    async def health(self) -> ProviderHealth: ...


class FixtureProvider(Protocol):
    name: str

    async def fetch_fixtures(self, competition_codes: Sequence[str]) -> list[dict]: ...

    async def health(self) -> ProviderHealth: ...
