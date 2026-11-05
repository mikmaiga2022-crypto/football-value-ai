"""Service de prédiction statistique (Phase 4)."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.ids import new_id
from app.db.models import Market, Match, ModelVersion, Prediction, PredictionContext, Team
from app.domain.predictions import compute_probabilities, features_hash, row_hash, update_elo

MODEL_CODE = "baseline-poisson-elo"


async def _ensure_model(session: AsyncSession) -> ModelVersion:
    stmt = select(ModelVersion).where(ModelVersion.code == MODEL_CODE)
    model = (await session.execute(stmt)).scalars().first()
    if model is None:
        model = ModelVersion(id=new_id("mdl"), code=MODEL_CODE, status="active", metrics={})
        session.add(model)
        await session.flush()
    return model


async def compute_predictions(
    session: AsyncSession, competition_codes: list[str] | None = None
) -> dict[str, int]:
    model = await _ensure_model(session)
    for code, name, family in (("1X2", "Resultat final", "result"), ("OU", "Over/Under", "totals")):
        if await session.get(Market, code) is None:
            session.add(Market(code=code, name=name, family=family))
    await session.flush()
    stmt = select(Match).where(Match.status.in_(("scheduled", "live", "halftime")))
    if competition_codes:
        stmt = stmt.where(Match.competition_code.in_(competition_codes))
    matches = (await session.execute(stmt)).scalars().all()

    created = 0
    for match in matches:
        home = await session.get(Team, match.home_team_id)
        away = await session.get(Team, match.away_team_id)
        if home is None or away is None:
            continue
        probs = compute_probabilities(float(home.elo_rating), float(away.elo_rating))
        payload = {
            "home_elo": float(home.elo_rating),
            "away_elo": float(away.elo_rating),
            "lambda_home": probs.lambda_home,
            "lambda_away": probs.lambda_away,
            "data_quality_score": float(match.data_quality_score),
        }
        fhash = features_hash(payload)

        selections: list[tuple[str, str | None, float]] = [
            ("1X2", None, probs.home_win),
            ("1X2", None, probs.draw),
            ("1X2", None, probs.away_win),
            ("OU", 2.5, probs.over_2_5),
            ("OU", 2.5, probs.under_2_5),
        ]
        # Map selection codes per market.
        for market_code, line, probability in selections:
            if market_code == "1X2":
                if probability == probs.home_win:
                    selection_code = "HOME"
                elif probability == probs.draw:
                    selection_code = "DRAW"
                else:
                    selection_code = "AWAY"
            else:
                selection_code = "OVER" if probability == probs.over_2_5 else "UNDER"

            # Vérifie l'existence pour éviter les doublons exacts.
            existing_stmt = select(Prediction).where(
                Prediction.match_id == match.id,
                Prediction.model_version_id == model.id,
                Prediction.market_code == market_code,
                Prediction.selection_code == selection_code,
                Prediction.line == line,
            )
            existing = (await session.execute(existing_stmt)).scalars().first()
            if existing is not None:
                continue

            ci = 0.05
            ci_low = max(0.0, probability - ci)
            ci_high = min(1.0, probability + ci)
            prediction = Prediction(
                id=new_id("pred"),
                match_id=match.id,
                model_version_id=model.id,
                market_code=market_code,
                line=line,
                selection_code=selection_code,
                probability=probability,
                ci_low=ci_low,
                ci_high=ci_high,
                data_quality_score=match.data_quality_score,
                features_hash=fhash,
                row_hash=row_hash(payload, None),
            )
            session.add(prediction)
            await session.flush()
            session.add(PredictionContext(prediction_id=prediction.id, features=payload))
            created += 1

    await session.flush()
    return {"predictions_created": created}


async def update_elo_ratings(session: AsyncSession) -> dict[str, int]:
    stmt = select(Match).where(Match.status == "finished")
    matches = (await session.execute(stmt)).scalars().all()
    updated = 0
    for match in matches:
        if match.home_score is None or match.away_score is None:
            continue
        home = await session.get(Team, match.home_team_id)
        away = await session.get(Team, match.away_team_id)
        if home is None or away is None:
            continue
        new_home, new_away = update_elo(
            float(home.elo_rating),
            float(away.elo_rating),
            match.home_score,
            match.away_score,
        )
        home.elo_rating = new_home
        away.elo_rating = new_away
        updated += 1
    await session.flush()
    return {"matches_processed": updated}
