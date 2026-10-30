"""Services d'ingestion (Phase 3) : fixtures et cotes, sans aucune donnée inventée."""

from __future__ import annotations

import re
from datetime import datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.ids import new_id
from app.core.time import utcnow
from app.db.models import (
    Bookmaker,
    DataSource,
    IngestionRun,
    Market,
    Match,
    OddsSnapshot,
    Team,
)
from app.ingestion.seed import ensure_default_competitions
from app.providers.api_football import ApiFootballClient
from app.providers.api_football import ProviderNotConfigured as AFNotConfigured
from app.providers.odds_api import OddsApiClient
from app.providers.odds_api import ProviderNotConfigured as OddsNotConfigured
from app.services.quota import QuotaService

SERVED_DEFAULT = ["FR1", "EPL", "CAN"]

_MARKETS_SEED = [
    ("1X2", "Résultat final (1X2)", "result"),
    ("OU", "Over/Under", "totals"),
]


def _slug(value: str) -> str:
    cleaned = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return cleaned or "unknown"


def _team_id(name: str) -> str:
    return f"team_{_slug(name)}"


async def _ensure_data_source(session: AsyncSession, code: str, name: str) -> None:
    existing = await session.get(DataSource, code)
    if existing is None:
        session.add(DataSource(code=code, name=name, reliability_weight=1.0))


async def _ensure_market(session: AsyncSession, code: str, name: str, family: str) -> None:
    existing = await session.get(Market, code)
    if existing is None:
        session.add(Market(code=code, name=name, family=family))


async def _ensure_bookmaker(session: AsyncSession, code: str, name: str) -> None:
    existing = await session.get(Bookmaker, code)
    if existing is None:
        session.add(Bookmaker(code=code, name=name, access_channel="api", countries=[]))


async def _upsert_team(
    session: AsyncSession, name: str, external_id: int | None, source: str
) -> Team:
    team_id = _team_id(name)
    team = await session.get(Team, team_id)
    if team is None:
        team = Team(id=team_id, name=name, short_name=name[:40], external_refs={})
        session.add(team)
    refs = dict(team.external_refs or {})
    if external_id is not None:
        refs[source] = str(external_id)
    team.external_refs = refs
    team.name = name
    return team


async def _find_match(
    session: AsyncSession, competition_code: str, home_id: str, away_id: str, kickoff: datetime
) -> Match | None:
    # Recherche par clé naturelle (compétition + équipes + heure exacte).
    stmt = select(Match).where(
        Match.competition_code == competition_code,
        Match.home_team_id == home_id,
        Match.away_team_id == away_id,
        Match.kickoff_utc == kickoff,
    )
    result = await session.execute(stmt)
    return result.scalars().first()


async def sync_fixtures(
    session: AsyncSession, competition_codes: list[str], season: int
) -> dict[str, Any]:
    await _ensure_data_source(session, "api_football", "API-Football")
    await ensure_default_competitions(session)
    for code, name, family in _MARKETS_SEED:
        await _ensure_market(session, code, name, family)

    client = ApiFootballClient()
    run = IngestionRun(
        id=new_id("run"),
        source_id="api_football",
        job_name="sync_fixtures",
        started_at=utcnow(),
        status="running",
    )
    session.add(run)
    await session.flush()

    matches_upserted = 0
    try:
        fixtures = await client.fetch_fixtures(competition_codes, season)
    except (AFNotConfigured, Exception) as exc:  # noqa: BLE001
        run.status = "failed"
        run.error = str(exc)
        run.finished_at = utcnow()
        await session.flush()
        return {"status": "failed", "error": str(exc), "matches_upserted": 0}

    for fx in fixtures:
        home_name = fx.get("home_team")
        away_name = fx.get("away_team")
        if not home_name or not away_name:
            continue
        home = await _upsert_team(session, home_name, fx.get("home_team_id"), "api_football")
        away = await _upsert_team(session, away_name, fx.get("away_team_id"), "api_football")
        kickoff = fx.get("kickoff_utc")
        if kickoff is None:
            continue
        existing = await _find_match(session, fx["competition_code"], home.id, away.id, kickoff)
        if existing is None:
            match = Match(
                id=new_id("match"),
                competition_code=fx["competition_code"],
                season=fx.get("season"),
                round=fx.get("round"),
                kickoff_utc=kickoff,
                venue_timezone=fx.get("venue_timezone") or "UTC",
                home_team_id=home.id,
                away_team_id=away.id,
                status=fx.get("status", "scheduled"),
                minute=fx.get("minute"),
                home_score=fx.get("home_score"),
                away_score=fx.get("away_score"),
                home_score_ht=fx.get("home_score_ht"),
                away_score_ht=fx.get("away_score_ht"),
                data_quality_score=0.6,
                source_id="api_football",
                source_event_id=fx["source_event_id"],
                last_synced_at=utcnow(),
            )
            session.add(match)
        else:
            existing.status = fx.get("status", existing.status)
            existing.minute = fx.get("minute", existing.minute)
            existing.home_score = fx.get("home_score", existing.home_score)
            existing.away_score = fx.get("away_score", existing.away_score)
            existing.home_score_ht = fx.get("home_score_ht", existing.home_score_ht)
            existing.away_score_ht = fx.get("away_score_ht", existing.away_score_ht)
            existing.last_synced_at = utcnow()
            match = existing
        matches_upserted += 1

    run.matches_upserted = matches_upserted
    run.status = "success"
    run.finished_at = utcnow()
    await session.flush()
    return {"status": "success", "matches_upserted": matches_upserted}


async def sync_odds(session: AsyncSession, competition_codes: list[str]) -> dict[str, Any]:
    await _ensure_data_source(session, "the_odds_api", "The Odds API")
    await ensure_default_competitions(session)
    for code, name, family in _MARKETS_SEED:
        await _ensure_market(session, code, name, family)

    client = OddsApiClient()
    run = IngestionRun(
        id=new_id("run"),
        source_id="the_odds_api",
        job_name="sync_odds",
        started_at=utcnow(),
        status="running",
    )
    session.add(run)
    await session.flush()

    # Estimation du coût : régions × marchés par compétition.
    regions = len(settings.odds_api_regions.split(","))
    markets = len(settings.odds_api_markets.split(","))
    estimated_credits = len(competition_codes) * regions * markets

    quota = QuotaService(session, provider="the_odds_api")
    try:
        await quota.spend(estimated_credits, note="sync_odds batch")
    except Exception as exc:  # QuotaExceeded
        run.status = "skipped"
        run.error = str(exc)
        run.finished_at = utcnow()
        await session.flush()
        return {"status": "skipped", "error": str(exc), "odds_appended": 0}

    try:
        odds = await client.fetch_odds(competition_codes)
    except (OddsNotConfigured, Exception) as exc:  # noqa: BLE001
        run.status = "failed"
        run.error = str(exc)
        run.finished_at = utcnow()
        await session.flush()
        return {"status": "failed", "error": str(exc), "odds_appended": 0}

    appended = 0
    for raw in odds:
        if (
            raw.competition_code is None
            or raw.home_team is None
            or raw.away_team is None
            or raw.kickoff_utc is None
        ):
            continue
        home = await _upsert_team(session, raw.home_team, None, "the_odds_api")
        away = await _upsert_team(session, raw.away_team, None, "the_odds_api")
        match = await _find_match(session, raw.competition_code, home.id, away.id, raw.kickoff_utc)
        if match is None:
            match = Match(
                id=new_id("match"),
                competition_code=raw.competition_code,
                kickoff_utc=raw.kickoff_utc,
                venue_timezone="UTC",
                home_team_id=home.id,
                away_team_id=away.id,
                status="scheduled",
                data_quality_score=0.4,
                source_id="the_odds_api",
                source_event_id=raw.source_event_id,
                last_synced_at=utcnow(),
            )
            session.add(match)
            await session.flush()

        await _ensure_bookmaker(session, raw.bookmaker, raw.bookmaker)
        market_code = raw.market
        if market_code not in {"1X2", "OU"}:
            continue
        await _ensure_market(
            session, market_code, market_code, "result" if market_code == "1X2" else "totals"
        )

        snapshot = OddsSnapshot(
            id=new_id("odd"),
            match_id=match.id,
            bookmaker_code=raw.bookmaker,
            market_code=market_code,
            selection_code=raw.selection,
            line=raw.line,
            decimal_odds=raw.decimal_odds,
            is_verified=raw.is_verified,
            is_available=True,
            observed_at=raw.observed_at,
            source_id="the_odds_api",
            source_payload_hash=raw.raw_payload_hash,
        )
        session.add(snapshot)
        appended += 1

    run.odds_appended = appended
    run.credits_spent = estimated_credits
    run.status = "success"
    run.finished_at = utcnow()
    await session.flush()
    return {"status": "success", "odds_appended": appended, "credits_spent": estimated_credits}
