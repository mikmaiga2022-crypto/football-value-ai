"""Tâches Celery (Phase 3 : collecte réelle, gardée par le quota)."""

from __future__ import annotations

import asyncio
import logging

from sqlalchemy import select

from app.db.models import Competition
from app.db.session import dispose_engine, init_engine, session_scope
from app.domain.coverage import CompetitionRef, CoveragePolicy, plan_coverage
from app.ingestion.service import sync_fixtures, sync_odds
from app.jobs.celery_app import celery_app

logger = logging.getLogger("fva.jobs")


@celery_app.task(name="app.jobs.tasks.ping")
def ping() -> str:
    return "pong"


@celery_app.task(name="app.jobs.tasks.recompute_coverage_plan")
def recompute_coverage_plan() -> dict:
    """Recalcule `competitions.coverage_state` selon le budget de crédits courant."""
    return asyncio.run(_recompute())


async def _recompute() -> dict:
    init_engine()
    try:
        async with session_scope() as session:
            rows = (await session.execute(select(Competition))).scalars().all()
            plan = plan_coverage(
                [
                    CompetitionRef(
                        code=row.code,
                        name=row.name,
                        tier=row.tier,
                        demand_score=row.demand_score,
                        is_international=row.is_international,
                        is_active=row.is_active,
                    )
                    for row in rows
                ],
                CoveragePolicy(),
            )
            states = {a.code: a.state for a in plan.assignments}
            for row in rows:
                row.coverage_state = states.get(row.code, "catalog")
        logger.info(
            "plan de couverture recalculé",
            extra={
                "extra_fields": {
                    "served": list(plan.by_state("served")),
                    "cost": plan.monthly_credits,
                }
            },
        )
        return {
            "served": list(plan.by_state("served")),
            "opportunistic": list(plan.by_state("opportunistic")),
            "monthly_credits": plan.monthly_credits,
        }
    finally:
        await dispose_engine()


@celery_app.task(name="app.jobs.tasks.sync_fixtures")
def sync_fixtures_task(competition_codes: list[str] | None = None, season: int = 2026) -> dict:
    return asyncio.run(_sync_fixtures(competition_codes, season))


async def _sync_fixtures(competition_codes: list[str] | None, season: int) -> dict:
    init_engine()
    try:
        codes = competition_codes or ["FR1", "EPL", "CAN"]
        async with session_scope() as session:
            return await sync_fixtures(session, codes, season)
    finally:
        await dispose_engine()


@celery_app.task(name="app.jobs.tasks.sync_odds")
def sync_odds_task(competition_codes: list[str] | None = None) -> dict:
    return asyncio.run(_sync_odds(competition_codes))


async def _sync_odds(competition_codes: list[str] | None) -> dict:
    init_engine()
    try:
        codes = competition_codes or ["FR1", "EPL", "CAN"]
        async with session_scope() as session:
            return await sync_odds(session, codes)
    finally:
        await dispose_engine()
