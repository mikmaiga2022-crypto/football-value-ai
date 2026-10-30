"""Simulation de bankroll (Phase 7)."""

from __future__ import annotations

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession, meta, require_permission
from app.core.ids import new_id
from app.core.time import utcnow
from app.db.models import Bankroll, SimulatedBet, ValueBet
from app.schemas.common import Envelope
from app.schemas.simulation import BankrollOut, SimulatedBetOut

router = APIRouter(tags=["simulation"])


class CreateBankrollIn(BaseModel):
    name: str
    initial_capital: float
    kelly_fraction: float = 0.25


class PlaceBetIn(BaseModel):
    bankroll_id: str
    value_bet_id: str
    stake: float


@router.get(
    "/bankrolls",
    response_model=Envelope[list[BankrollOut]],
    dependencies=[Depends(require_permission("simulation.write"))],
)
async def list_bankrolls(session: DbSession, user: CurrentUser) -> Envelope[list[BankrollOut]]:
    stmt = select(Bankroll).where(Bankroll.user_id == user.id)
    rows = (await session.execute(stmt)).scalars().all()
    return Envelope(data=[BankrollOut.model_validate(r) for r in rows], meta=meta())


@router.post(
    "/bankrolls",
    response_model=Envelope[BankrollOut],
    dependencies=[Depends(require_permission("simulation.write"))],
)
async def create_bankroll(
    session: DbSession, user: CurrentUser, payload: CreateBankrollIn
) -> Envelope[BankrollOut]:
    bankroll = Bankroll(
        id=new_id("bk"),
        user_id=user.id,
        name=payload.name,
        initial_capital=payload.initial_capital,
        current_capital=payload.initial_capital,
        kelly_fraction=payload.kelly_fraction,
    )
    session.add(bankroll)
    await session.commit()
    return Envelope(data=BankrollOut.model_validate(bankroll), meta=meta())


@router.get(
    "/simulated-bets",
    response_model=Envelope[list[SimulatedBetOut]],
    dependencies=[Depends(require_permission("simulation.write"))],
)
async def list_bets(session: DbSession, user: CurrentUser) -> Envelope[list[SimulatedBetOut]]:
    stmt = (
        select(SimulatedBet)
        .where(SimulatedBet.user_id == user.id)
        .order_by(SimulatedBet.placed_at.desc())
    )
    rows = (await session.execute(stmt)).scalars().all()
    return Envelope(data=[SimulatedBetOut.model_validate(r) for r in rows], meta=meta())


@router.post(
    "/simulated-bets",
    response_model=Envelope[SimulatedBetOut],
    dependencies=[Depends(require_permission("simulation.write"))],
)
async def place_bet(
    session: DbSession, user: CurrentUser, payload: PlaceBetIn
) -> Envelope[SimulatedBetOut]:
    bankroll = await session.get(Bankroll, payload.bankroll_id)
    if bankroll is None or bankroll.user_id != user.id:
        from app.core.errors import ApiError

        raise ApiError(404, "NOT_FOUND", "Bankroll inconnue.")
    value_bet = await session.get(ValueBet, payload.value_bet_id)
    if value_bet is None:
        from app.core.errors import ApiError

        raise ApiError(404, "NOT_FOUND", "Value bet inconnue.")

    odds = float(value_bet.fair_odds)  # placeholder: use fair odds
    # retrieve odds snapshot decimal odds
    from app.db.models import OddsSnapshot

    snapshot = await session.get(OddsSnapshot, value_bet.odds_snapshot_id)
    if snapshot is not None:
        odds = float(snapshot.decimal_odds)

    bet = SimulatedBet(
        id=new_id("sb"),
        user_id=user.id,
        bankroll_id=payload.bankroll_id,
        value_bet_id=payload.value_bet_id,
        stake=payload.stake,
        odds_taken=odds,
        status="pending",
        placed_at=utcnow(),
    )
    session.add(bet)
    bankroll.current_capital = float(bankroll.current_capital) - payload.stake
    await session.commit()
    return Envelope(data=SimulatedBetOut.model_validate(bet), meta=meta())


@router.post(
    "/simulated-bets/settle",
    response_model=Envelope[dict],
    dependencies=[Depends(require_permission("admin.publish"))],
)
async def settle(session: DbSession, user: CurrentUser) -> Envelope[dict]:
    # Settlement minimal: marque les paris pending dont le match est terminé comme won/lost.
    from app.db.models import Match

    stmt = select(SimulatedBet).where(SimulatedBet.status == "pending")
    bets = (await session.execute(stmt)).scalars().all()
    settled = 0
    for bet in bets:
        value_bet = await session.get(ValueBet, bet.value_bet_id)
        if value_bet is None:
            continue
        match = await session.get(Match, value_bet.match_id)
        if match is None or match.status != "finished" or match.home_score is None:
            continue
        # Détermine le résultat selon la sélection.
        home = match.home_score
        away = match.away_score
        won = False
        if value_bet.market_code == "1X2":
            if (
                value_bet.selection_code == "HOME"
                and home > away
                or value_bet.selection_code == "DRAW"
                and home == away
                or value_bet.selection_code == "AWAY"
                and away > home
            ):
                won = True
        elif value_bet.market_code == "OU":
            total = home + away
            if (
                value_bet.selection_code == "OVER"
                and total > (value_bet.line or 2.5)
                or value_bet.selection_code == "UNDER"
                and total < (value_bet.line or 2.5)
            ):
                won = True
        bet.status = "won" if won else "lost"
        bet.payout = float(bet.stake) * float(bet.odds_taken) if won else 0.0
        bet.profit_loss = float(bet.payout or 0) - float(bet.stake)
        bet.settled_at = utcnow()
        bankroll = await session.get(Bankroll, bet.bankroll_id)
        if bankroll is not None:
            bankroll.current_capital = float(bankroll.current_capital) + float(bet.payout or 0)
        settled += 1
    await session.commit()
    return Envelope(data={"settled": settled}, meta=meta())
