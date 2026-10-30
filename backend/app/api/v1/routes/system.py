"""Couverture effective et état du quota fournisseur (docs/09 §4)."""

from __future__ import annotations

from fastapi import APIRouter
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession, meta
from app.core.config import settings
from app.db.models import Competition
from app.domain.coverage import CompetitionRef, CoveragePolicy, plan_coverage
from app.schemas.common import Envelope
from app.schemas.competition import CoverageEntry, CoverageQuota, CoverageResponse
from app.services.quota import QuotaService

router = APIRouter(tags=["system"])


@router.get(
    "/system/coverage",
    response_model=Envelope[CoverageResponse],
    summary="Compétitions réellement servies et crédits restants",
)
async def coverage(session: DbSession, user: CurrentUser) -> Envelope[CoverageResponse]:
    del user
    rows = (await session.execute(select(Competition))).scalars().all()
    refs = [
        CompetitionRef(
            code=row.code,
            name=row.name,
            tier=row.tier,
            demand_score=row.demand_score,
            is_international=row.is_international,
            is_active=row.is_active,
        )
        for row in rows
    ]
    names = {row.code: row.name for row in rows}
    policy = CoveragePolicy(
        served_slots=settings.coverage_served_slots,
        opportunistic_slots=settings.coverage_opportunistic_slots,
        monthly_budget_credits=settings.odds_monthly_credit_budget,
    )
    plan = plan_coverage(refs, policy)

    quota = await QuotaService(session).status()

    def entries(state: str) -> list[CoverageEntry]:
        return [
            CoverageEntry(
                code=a.code, name=names.get(a.code, a.code), state=a.state, reason=a.reason
            )
            for a in plan.assignments
            if a.state == state
        ]

    data = CoverageResponse(
        served=entries("served"),
        opportunistic=entries("opportunistic"),
        catalog=entries("catalog"),
        disabled=entries("disabled"),
        monthly_credits=plan.monthly_credits,
        monthly_budget=plan.monthly_budget,
        headroom=plan.headroom,
        quota=CoverageQuota(
            provider=quota.provider,
            used_today=quota.used_today,
            used_month=quota.used_month,
            monthly_budget=quota.monthly_budget,
            monthly_limit=quota.monthly_limit,
            remaining=quota.remaining,
            exhausted=quota.exhausted,
            degraded_reason=quota.degraded_reason,
        ),
        notes=list(plan.notes),
    )
    return Envelope(
        data=data,
        meta=meta(
            degraded=quota.exhausted,
            degraded_reason=quota.degraded_reason,
        ),
    )
