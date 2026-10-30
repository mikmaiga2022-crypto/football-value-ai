"""Santé et méta-information publique (docs/04 §3.10)."""

from __future__ import annotations

import time

from fastapi import APIRouter
from sqlalchemy import text

from app.api.deps import DbSession, meta
from app.core.config import settings
from app.schemas.common import Envelope
from app.schemas.system import AppConfigResponse, DisclaimerResponse, FeatureFlags, HealthResponse

router = APIRouter(tags=["meta"])

DISCLAIMER_TEXT = (
    "FOOTBALL VALUE AI est un outil d'aide à la décision. Les probabilités affichées sont "
    "des estimations, pas des certitudes. Aucun gain n'est garanti et une espérance positive "
    "ne garantit pas un gain sur un pari individuel. L'application ne place aucun pari et peut "
    "recommander de ne pas parier. Les cotes sont datées : vérifiez-les avant toute décision."
)

#: Horodatage de démarrage, rempli par `create_app` (monotone pour l'uptime).
STARTED_AT: dict[str, float] = {}


@router.get("/health", response_model=Envelope[HealthResponse], summary="Santé publique")
async def health(session: DbSession) -> Envelope[HealthResponse]:
    database = "ok"
    try:
        await session.execute(text("SELECT 1"))
    except Exception:  # pragma: no cover - dépend de l'infrastructure
        database = "unavailable"

    started = STARTED_AT.get("at", time.time())
    payload = HealthResponse(
        status="ok" if database == "ok" else "degraded",
        database=database,
        environment=settings.environment,
        api_version=settings.api_version,
        uptime_seconds=int(time.time() - started),
    )
    return Envelope(
        data=payload,
        meta=meta(
            degraded=database != "ok",
            degraded_reason=None if database == "ok" else "Base de données indisponible.",
        ),
    )


@router.get("/meta/config", response_model=Envelope[AppConfigResponse])
async def app_config() -> Envelope[AppConfigResponse]:
    data = AppConfigResponse(
        min_app_version="0.1.0",
        latest_app_version="0.1.0",
        maintenance=False,
        features=FeatureFlags(),
        legal={
            "terms": "/legal/terms",
            "privacy": "/legal/privacy",
            "responsible_gambling": "/legal/responsible-gambling",
        },
        data_mode="standard" if settings.odds_monthly_credit_budget >= 20000 else "zero_budget",
    )
    return Envelope(data=data, meta=meta())


@router.get("/meta/disclaimer", response_model=Envelope[DisclaimerResponse])
async def disclaimer() -> Envelope[DisclaimerResponse]:
    data = DisclaimerResponse(
        version="1.0.0",
        updated_at="2026-10-30T00:00:00Z",
        text=DISCLAIMER_TEXT,
    )
    return Envelope(data=data, meta=meta())
