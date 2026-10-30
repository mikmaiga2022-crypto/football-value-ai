"""Connecteur API-Football (fixtures, stats)."""

from __future__ import annotations

from datetime import datetime
from typing import Any

import httpx

from app.core.config import settings
from app.providers.base import ProviderHealth


class ProviderNotConfigured(Exception):
    pass


class ApiFootballClient:
    name = "api_football"

    def __init__(self) -> None:
        self._key = settings.api_football_key
        self._base = settings.api_football_base_url.rstrip("/")
        self._timeout = settings.provider_timeout_seconds

    async def health(self) -> ProviderHealth:
        if not self._key:
            return ProviderHealth(name=self.name, healthy=False, message="clé absente")
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.get(
                    f"{self._base}/status",
                    headers={"x-apisports-key": self._key},
                )
            return ProviderHealth(
                name=self.name,
                healthy=response.status_code == 200,
                message=None if response.status_code == 200 else response.text[:120],
            )
        except Exception as exc:  # pragma: no cover
            return ProviderHealth(name=self.name, healthy=False, message=str(exc))

    async def fetch_fixtures(
        self, competition_codes: list[str], season: int
    ) -> list[dict[str, Any]]:
        if not self._key:
            raise ProviderNotConfigured(self.name)
        collected: list[dict[str, Any]] = []
        async with httpx.AsyncClient(timeout=self._timeout) as client:
            for code in competition_codes:
                league_id = settings.api_football_league_ids.get(code)
                if league_id is None:
                    continue
                response = await client.get(
                    f"{self._base}/fixtures",
                    headers={"x-apisports-key": self._key},
                    params={"league": league_id, "season": season},
                )
                response.raise_for_status()
                payload = response.json()
                for item in payload.get("response", []):
                    collected.append(_normalize(code, item))
        return collected


def _normalize(competition_code: str, item: dict[str, Any]) -> dict[str, Any]:
    fixture = item.get("fixture", {})
    teams = item.get("teams", {})
    goals = item.get("goals", {})
    score = item.get("score", {})
    halftime = score.get("halftime", {}) or {}
    status_short = (fixture.get("status") or {}).get("short", "NS")
    status = _map_status(status_short)
    kickoff = _parse_dt(fixture.get("date"))
    return {
        "competition_code": competition_code,
        "source_event_id": str(fixture.get("id")),
        "home_team": (teams.get("home") or {}).get("name"),
        "home_team_id": (teams.get("home") or {}).get("id"),
        "away_team": (teams.get("away") or {}).get("name"),
        "away_team_id": (teams.get("away") or {}).get("id"),
        "kickoff_utc": kickoff,
        "status": status,
        "minute": (fixture.get("status") or {}).get("elapsed"),
        "home_score": goals.get("home"),
        "away_score": goals.get("away"),
        "home_score_ht": halftime.get("home"),
        "away_score_ht": halftime.get("away"),
        "round": (item.get("league") or {}).get("round"),
        "season": str((item.get("league") or {}).get("season")),
        "venue_timezone": (fixture.get("timezone") or "UTC"),
    }


def _map_status(short: str) -> str:
    mapping = {
        "NS": "scheduled",
        "TBD": "scheduled",
        "1H": "live",
        "HT": "halftime",
        "2H": "live",
        "ET": "live",
        "BT": "live",
        "P": "live",
        "SUSP": "suspended",
        "INT": "suspended",
        "FT": "finished",
        "AET": "finished",
        "PEN": "finished",
        "PST": "postponed",
        "CANC": "cancelled",
        "ABD": "cancelled",
        "AWD": "finished",
        "WO": "finished",
    }
    return mapping.get(short, "scheduled")


def _parse_dt(value: Any) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
