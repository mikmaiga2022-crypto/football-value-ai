"""Connecteur The Odds API (cotes pré-match)."""

from __future__ import annotations

import hashlib
import json
from datetime import datetime
from typing import Any

import httpx

from app.core.config import settings
from app.core.time import utcnow
from app.providers.base import ProviderHealth, RawOdd


class ProviderNotConfigured(Exception):
    """Clé API absente : aucun appel réseau n'est tenté."""


class OddsApiClient:
    name = "the_odds_api"

    def __init__(self) -> None:
        self._key = settings.odds_api_key
        self._base = settings.odds_api_base_url.rstrip("/")
        self._regions = settings.odds_api_regions
        self._markets = settings.odds_api_markets
        self._timeout = settings.provider_timeout_seconds

    async def health(self) -> ProviderHealth:
        if not self._key:
            return ProviderHealth(name=self.name, healthy=False, message="clé absente")
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.get(f"{self._base}/sports", params={"apiKey": self._key})
            return ProviderHealth(
                name=self.name,
                healthy=response.status_code == 200,
                credits_remaining=_credits_remaining(response),
                message=None if response.status_code == 200 else response.text[:120],
            )
        except Exception as exc:  # pragma: no cover - dépend du réseau
            return ProviderHealth(name=self.name, healthy=False, message=str(exc))

    async def fetch_odds(self, competition_codes: list[str]) -> list[RawOdd]:
        if not self._key:
            raise ProviderNotConfigured(self.name)
        collected: list[RawOdd] = []
        async with httpx.AsyncClient(timeout=self._timeout) as client:
            for code in competition_codes:
                sport_key = settings.odds_api_sport_keys.get(code)
                if not sport_key:
                    continue
                response = await client.get(
                    f"{self._base}/sports/{sport_key}/odds/",
                    params={
                        "regions": self._regions,
                        "markets": self._markets,
                        "oddsFormat": "decimal",
                        "apiKey": self._key,
                    },
                )
                response.raise_for_status()
                payload = response.json()
                collected.extend(_parse_events(code, payload, response.headers))
        return collected


def _credits_remaining(response: httpx.Response) -> int | None:
    remaining = response.headers.get("x-requests-remaining")
    return int(remaining) if remaining and remaining.isdigit() else None


def _parse_events(
    competition_code: str, events: list[dict[str, Any]], headers: Any
) -> list[RawOdd]:
    observed = utcnow()
    result: list[RawOdd] = []
    for event in events:
        event_id = str(event.get("id"))
        home = event.get("home_team")
        away = event.get("away_team")
        kickoff = _parse_dt(event.get("commence_time"))
        for bookmaker in event.get("bookmakers", []):
            bookmaker_code = str(bookmaker.get("key"))
            for market in bookmaker.get("markets", []):
                market_code = _map_market(str(market.get("key")))
                for outcome in market.get("outcomes", []):
                    selection = _map_selection(outcome.get("name"), home, away)
                    line = outcome.get("point")
                    decimal = float(outcome.get("price"))
                    raw_hash = hashlib.sha256(
                        json.dumps(outcome, sort_keys=True, default=str).encode()
                    ).hexdigest()
                    result.append(
                        RawOdd(
                            source="the_odds_api",
                            source_event_id=event_id,
                            bookmaker=bookmaker_code,
                            market=market_code,
                            selection=selection,
                            decimal_odds=decimal,
                            observed_at=observed,
                            raw_payload_hash=raw_hash,
                            line=float(line) if line is not None else None,
                            is_verified=False,
                            competition_code=competition_code,
                            home_team=home,
                            away_team=away,
                            kickoff_utc=kickoff,
                            metadata={"title": str(event.get("sport_title", ""))},
                        )
                    )
    return result


def _map_market(key: str) -> str:
    return {"h2h": "1X2", "totals": "OU"}.get(key, key.upper())


def _map_selection(name: Any, home: Any, away: Any) -> str:
    text = str(name).strip().lower()
    if text == "draw":
        return "DRAW"
    if home and text == str(home).strip().lower():
        return "HOME"
    if away and text == str(away).strip().lower():
        return "AWAY"
    if text.startswith("over"):
        return "OVER"
    if text.startswith("under"):
        return "UNDER"
    return text.upper()


def _parse_dt(value: Any) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
