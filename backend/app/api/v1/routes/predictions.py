"""Prédictions statistiques (Phase 4)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession, meta, require_permission
from app.db.models import Prediction
from app.schemas.common import Envelope
from app.schemas.prediction import ComputePredictionsResponse, PredictionOut
from app.services.predictions import compute_predictions, update_elo_ratings

router = APIRouter(tags=["predictions"])


@router.get(
    "/predictions",
    response_model=Envelope[list[PredictionOut]],
    dependencies=[Depends(require_permission("predictions.read"))],
)
async def list_predictions(
    session: DbSession,
    user: CurrentUser,
    match_id: Annotated[str | None, Query()] = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 100,
) -> Envelope[list[PredictionOut]]:
    stmt = select(Prediction).order_by(Prediction.created_at.desc()).limit(limit)
    if match_id:
        stmt = stmt.where(Prediction.match_id == match_id)
    rows = (await session.execute(stmt)).scalars().all()
    degraded = len(rows) == 0
    return Envelope(
        data=[PredictionOut.model_validate(r) for r in rows],
        meta=meta(
            degraded=degraded, degraded_reason="Aucune prédiction disponible." if degraded else None
        ),
    )


@router.post(
    "/predictions/compute",
    response_model=Envelope[ComputePredictionsResponse],
    dependencies=[Depends(require_permission("admin.publish"))],
)
async def compute(
    session: DbSession,
    user: CurrentUser,
    competition: Annotated[str | None, Query()] = None,
) -> Envelope[ComputePredictionsResponse]:
    codes = [competition] if competition else None
    result = await compute_predictions(session, codes)
    await session.commit()
    return Envelope(data=ComputePredictionsResponse(**result), meta=meta())


@router.post(
    "/predictions/elo/update",
    response_model=Envelope[dict],
    dependencies=[Depends(require_permission("admin.publish"))],
)
async def update_elo(session: DbSession, user: CurrentUser) -> Envelope[dict]:
    result = await update_elo_ratings(session)
    await session.commit()
    return Envelope(data=result, meta=meta())
