"""Value Betting (Phase 5)."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession, meta, require_permission
from app.db.models import Bookmaker, DataSource, Market, Match, OddsSnapshot
from app.schemas.common import Envelope
from app.schemas.value import ValueBetOut
from app.services.value import compute_value_bets

router = APIRouter(tags=["value"])


@router.get(
    "/value-bets",
    response_model=Envelope[list[ValueBetOut]],
    dependencies=[Depends(require_permission("value.read"))],
)
async def list_value_bets(
    session: DbSession,
    user: CurrentUser,
    match_id: str | None = Query(default=None),
    priority: str | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
) -> Envelope[list[ValueBetOut]]:
    from app.db.models import ValueBet

    stmt = select(ValueBet).order_by(ValueBet.score.desc()).limit(limit)
    if match_id:
        stmt = stmt.where(ValueBet.match_id == match_id)
    if priority:
        stmt = stmt.where(ValueBet.priority == priority)
    rows = (await session.execute(stmt)).scalars().all()
    degraded = len(rows) == 0
    return Envelope(
        data=[ValueBetOut.model_validate(r) for r in rows],
        meta=meta(
            degraded=degraded, degraded_reason="Aucune opportunité publiée." if degraded else None
        ),
    )


@router.post(
    "/value-bets/compute",
    response_model=Envelope[dict],
    dependencies=[Depends(require_permission("admin.publish"))],
)
async def compute(
    session: DbSession,
    user: CurrentUser,
    competition: Annotated[str | None, Query()] = None,
) -> Envelope[dict]:
    codes = [competition] if competition else None
    result = await compute_value_bets(session, codes)
    await session.commit()
    return Envelope(data=result, meta=meta())


@router.post(
    "/odds/manual",
    response_model=Envelope[dict],
    dependencies=[Depends(require_permission("admin.odds.write"))],
)
async def manual_odds(
    session: DbSession,
    user: CurrentUser,
    match_id: str,
    bookmaker_code: str,
    market_code: str,
    selection_code: str,
    decimal_odds: float,
    observed_at: datetime,
    attested: bool = False,
    line: float | None = None,
) -> Envelope[dict]:
    from app.core.ids import new_id

    # Assure les référentiels.
    if await session.get(DataSource, "manual") is None:
        session.add(DataSource(code="manual", name="Saisie manuelle", reliability_weight=0.8))
    if await session.get(Bookmaker, bookmaker_code) is None:
        session.add(
            Bookmaker(
                code=bookmaker_code, name=bookmaker_code, access_channel="manual", countries=[]
            )
        )
    if await session.get(Market, market_code) is None:
        session.add(Market(code=market_code, name=market_code, family="manual"))
    await session.flush()

    match = await session.get(Match, match_id)
    if match is None:
        from app.core.errors import ApiError

        raise ApiError(404, "NOT_FOUND", "Rencontre inconnue.")

    snapshot = OddsSnapshot(
        id=new_id("odd"),
        match_id=match_id,
        bookmaker_code=bookmaker_code,
        market_code=market_code,
        selection_code=selection_code,
        line=line,
        decimal_odds=decimal_odds,
        is_verified=attested,
        is_available=True,
        observed_at=observed_at,
        source_id="manual",
        source_payload_hash="manual",
    )
    session.add(snapshot)
    await session.commit()
    return Envelope(data={"id": snapshot.id}, meta=meta())
