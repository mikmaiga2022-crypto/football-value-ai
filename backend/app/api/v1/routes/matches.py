"""Rencontres et cotes (Phase 3)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession, meta, require_permission
from app.db.models import Match, OddsSnapshot, Team
from app.schemas.common import Envelope
from app.schemas.match import MatchOut, OddsLatestResponse, OddsSnapshotOut, TeamOut

router = APIRouter(tags=["matches"])


def _to_match_out(match: Match, home: Team, away: Team) -> MatchOut:
    return MatchOut(
        id=match.id,
        competition_code=match.competition_code,
        season=match.season,
        round=match.round,
        kickoff_utc=match.kickoff_utc,
        status=match.status,  # type: ignore[arg-type]
        minute=match.minute,
        home_team=TeamOut.model_validate(home),
        away_team=TeamOut.model_validate(away),
        home_score=match.home_score,
        away_score=match.away_score,
        home_score_ht=match.home_score_ht,
        away_score_ht=match.away_score_ht,
        data_quality_score=float(match.data_quality_score),
        source_id=match.source_id,
        last_synced_at=match.last_synced_at,
    )


@router.get(
    "/matches",
    response_model=Envelope[list[MatchOut]],
    summary="Liste des rencontres collectées (réelles uniquement)",
    dependencies=[Depends(require_permission("matches.read"))],
)
async def list_matches(
    session: DbSession,
    user: CurrentUser,
    competition: Annotated[str | None, Query()] = None,
    status: Annotated[str | None, Query()] = None,
    from_date: Annotated[datetime | None, Query(alias="from")] = None,
    to_date: Annotated[datetime | None, Query(alias="to")] = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> Envelope[list[MatchOut]]:
    stmt = select(Match, Team).join(Team, Team.id == Match.home_team_id)
    # On refait proprement avec deux jointures.
    stmt = select(Match).order_by(Match.kickoff_utc.asc()).limit(limit)
    if competition:
        stmt = stmt.where(Match.competition_code == competition)
    if status:
        stmt = stmt.where(Match.status == status)
    if from_date:
        stmt = stmt.where(Match.kickoff_utc >= from_date)
    if to_date:
        stmt = stmt.where(Match.kickoff_utc <= to_date)

    matches = (await session.execute(stmt)).scalars().all()
    # Charge les équipes en lot.
    team_ids = {m.home_team_id for m in matches} | {m.away_team_id for m in matches}
    teams = {}
    if team_ids:
        rows = (await session.execute(select(Team).where(Team.id.in_(team_ids)))).scalars().all()
        teams = {t.id: t for t in rows}

    degraded = len(matches) == 0
    return Envelope(
        data=[_to_match_out(m, teams[m.home_team_id], teams[m.away_team_id]) for m in matches],
        meta=meta(
            degraded=degraded,
            degraded_reason="Aucune rencontre collectée pour le moment." if degraded else None,
        ),
    )


@router.get(
    "/matches/{match_id}",
    response_model=Envelope[MatchOut],
    dependencies=[Depends(require_permission("matches.read"))],
)
async def get_match(match_id: str, session: DbSession, user: CurrentUser) -> Envelope[MatchOut]:
    match = await session.get(Match, match_id)
    if match is None:
        from app.core.errors import ApiError

        raise ApiError(404, "NOT_FOUND", "Rencontre inconnue.")
    home = await session.get(Team, match.home_team_id)
    away = await session.get(Team, match.away_team_id)
    assert home is not None and away is not None
    return Envelope(data=_to_match_out(match, home, away), meta=meta())


@router.get(
    "/odds/latest",
    response_model=Envelope[OddsLatestResponse],
    summary="Dernières cotes observées pour une rencontre",
    dependencies=[Depends(require_permission("odds.read"))],
)
async def latest_odds(
    session: DbSession,
    user: CurrentUser,
    match_id: Annotated[str, Query()],
    market: Annotated[str | None, Query()] = None,
    max_age_seconds: Annotated[int, Query(ge=60, le=86400)] = 3600,
) -> Envelope[OddsLatestResponse]:
    cutoff = datetime.now(UTC) - timedelta(seconds=max_age_seconds)
    stmt = select(OddsSnapshot).where(
        OddsSnapshot.match_id == match_id,
        OddsSnapshot.observed_at >= cutoff,
        OddsSnapshot.is_available.is_(True),
    )
    if market:
        stmt = stmt.where(OddsSnapshot.market_code == market)
    stmt = stmt.order_by(OddsSnapshot.observed_at.desc())
    rows = (await session.execute(stmt)).scalars().all()

    snapshots = [OddsSnapshotOut.model_validate(r) for r in rows]
    degraded = len(snapshots) == 0
    return Envelope(
        data=OddsLatestResponse(match_id=match_id, snapshots=snapshots),
        meta=meta(
            degraded=degraded,
            degraded_reason=("Aucune cote récente pour cette rencontre." if degraded else None),
            freshness_seconds=max_age_seconds,
        ),
    )
