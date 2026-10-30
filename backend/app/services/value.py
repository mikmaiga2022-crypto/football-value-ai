"""Service de Value Betting (Phase 5)."""

from __future__ import annotations

from collections import defaultdict
from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.ids import new_id
from app.core.time import utcnow
from app.db.models import Match, OddsSnapshot, Prediction, ValueBet
from app.domain.value.engine import (
    DataQualityInput,
    MarketThresholds,
    SelectionInput,
    score_selection,
)

MARKETS = {"1X2": ["HOME", "DRAW", "AWAY"], "OU": ["OVER", "UNDER"]}
SELECTIONS_NEEDED = {"1X2": 3, "OU": 2}


async def compute_value_bets(
    session: AsyncSession, competition_codes: list[str] | None = None
) -> dict[str, int]:
    stmt = select(Match).where(Match.status.in_(("scheduled", "live", "halftime")))
    if competition_codes:
        stmt = stmt.where(Match.competition_code.in_(competition_codes))
    matches = (await session.execute(stmt)).scalars().all()

    created = 0
    now = utcnow()
    cutoff = now - timedelta(seconds=900)

    for match in matches:
        # Prédictions les plus récentes par (marché, sélection).
        pred_stmt = (
            select(Prediction)
            .where(Prediction.match_id == match.id)
            .order_by(Prediction.created_at.desc())
        )
        preds = (await session.execute(pred_stmt)).scalars().all()
        pred_map: dict[tuple[str, str, float | None], Prediction] = {}
        for p in preds:
            key = (p.market_code, p.selection_code, float(p.line) if p.line is not None else None)
            if key not in pred_map:
                pred_map[key] = p

        # Cotes récentes.
        odds_stmt = select(OddsSnapshot).where(
            OddsSnapshot.match_id == match.id,
            OddsSnapshot.observed_at >= cutoff,
            OddsSnapshot.is_available.is_(True),
        )
        odds = (await session.execute(odds_stmt)).scalars().all()
        if not odds:
            continue

        # Groupe par (marché, bookmaker) -> sélection -> snapshot le plus récent.
        grouped: dict[tuple[str, str], dict[str, OddsSnapshot]] = defaultdict(dict)
        for snap in odds:
            if snap.market_code not in MARKETS:
                continue
            key = (snap.market_code, snap.bookmaker_code)
            existing = grouped[key].get(snap.selection_code)
            if existing is None or snap.observed_at > existing.observed_at:
                grouped[key][snap.selection_code] = snap

        dq = DataQualityInput(
            matches_played_home=10,
            matches_played_away=10,
            xg_available="none",
            lineup="none",
            injuries_complete_fresh=False,
            bookmakers_count=len({s.bookmaker_code for s in odds}),
            odds_age_seconds=0.0,
            max_age_seconds=900.0,
        )

        for (market_code, _), snaps in grouped.items():
            needed = MARKETS[market_code]
            if not all(sel in snaps for sel in needed):
                continue
            odds_list = [float(snaps[sel].decimal_odds) for sel in needed]
            market_margin = sum(1.0 / o for o in odds_list) - 1.0
            if market_margin > 0.08:
                continue
            no_vig = [1.0 / o / (1.0 + market_margin) for o in odds_list]
            # no-vig proportional is 1/o / sum(1/o); recompute properly:
            implied = [1.0 / o for o in odds_list]
            total = sum(implied)
            no_vig = [q / total for q in implied]

            observed_times = [s.observed_at for s in snaps.values()]
            age_seconds = (now - min(observed_times)).total_seconds()

            for idx, selection_code in enumerate(needed):
                snap = snaps[selection_code]
                line = float(snap.line) if snap.line is not None else None
                pred = pred_map.get((market_code, selection_code, line))
                if pred is None:
                    # fallback: any prediction for market/selection
                    pred = pred_map.get((market_code, selection_code, None))
                if pred is None:
                    continue

                item = SelectionInput(
                    odds=float(snap.decimal_odds),
                    probability=float(pred.probability),
                    probability_low=float(pred.ci_low),
                    probability_high=float(pred.ci_high),
                    market_probability=no_vig[idx],
                    data_quality=dq.score(),
                    market_margin=market_margin,
                    is_verified=bool(snap.is_verified),
                    bookmaker_manual=False,
                    odds_age_seconds=age_seconds,
                    bookmaker_accessible=True,
                    lineup_known=False,
                    thresholds=MarketThresholds(),
                )
                try:
                    score = score_selection(item)
                except Exception as exc:
                    import logging

                    logging.getLogger("fva.value").warning("score_selection echoue: %s", exc)
                    continue
                if score.priority == "NO_BET":
                    continue

                # Déduplique par snapshot.
                existing_stmt = select(ValueBet).where(
                    ValueBet.match_id == match.id,
                    ValueBet.odds_snapshot_id == snap.id,
                    ValueBet.market_code == market_code,
                    ValueBet.selection_code == selection_code,
                )
                if (await session.execute(existing_stmt)).scalars().first() is not None:
                    continue

                value_bet = ValueBet(
                    id=new_id("vb"),
                    match_id=match.id,
                    odds_snapshot_id=snap.id,
                    prediction_id=pred.id,
                    market_code=market_code,
                    selection_code=selection_code,
                    line=snap.line,
                    implied_prob_novig=no_vig[idx],
                    fair_odds=score.fair_odds,
                    ev=score.ev,
                    ev_lower=score.ev_lower,
                    edge=score.edge,
                    score=score.score,
                    priority=score.priority,
                    gate_results={"caps": list(score.caps), "penalties": list(score.penalties)},
                    explanation=score.explanation,
                    status="active",
                    created_at=now,
                )
                session.add(value_bet)
                created += 1

    await session.flush()
    return {"value_bets_created": created}
