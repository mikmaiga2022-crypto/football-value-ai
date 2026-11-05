"""Synchronisation manuelle (Phase 3/4/5) — pour la bêta sans worker Celery."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.deps import CurrentUser, DbSession, meta, require_permission
from app.db.session import session_scope
from app.ingestion.service import sync_fixtures, sync_odds
from app.services.predictions import compute_predictions
from app.services.value import compute_value_bets

router = APIRouter(tags=["admin-sync"])


@router.post("/admin/sync", dependencies=[Depends(require_permission("admin.publish"))])
async def sync_all(
    session: DbSession,
    user: CurrentUser,
    competition: Annotated[str | None, Query()] = None,
) -> dict:
    codes = [competition] if competition else ["FR1", "EPL", "CAN"]
    results: dict = {}
    async with session_scope() as s:
        results["fixtures"] = await sync_fixtures(s, codes, 2026)
        await s.commit()
    async with session_scope() as s:
        results["odds"] = await sync_odds(s, codes)
        await s.commit()
    async with session_scope() as s:
        results["predictions"] = await compute_predictions(s, codes)
        await s.commit()
    async with session_scope() as s:
        results["value"] = await compute_value_bets(s, codes)
        await s.commit()
    return {"data": results, "meta": meta().model_dump()}
