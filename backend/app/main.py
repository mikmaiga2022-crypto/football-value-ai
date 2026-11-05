"""Fabrique d'application FastAPI (Phase 2 : socle technique)."""

from __future__ import annotations

import logging
import time
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app import __version__
from app.api.middleware import install_middlewares
from app.api.v1.router import api_router
from app.api.v1.routes.meta import STARTED_AT
from app.core.config import settings
from app.core.errors import register_error_handlers
from app.core.logging import configure_logging
from app.db.session import create_all, dispose_engine, init_engine
from app.services.lockout import InMemoryLockout, RedisLockout

logger = logging.getLogger("fva.app")

DESCRIPTION = """
API de FOOTBALL VALUE AI.

**Phase 2 — socle technique.** Aucune donnée de match, aucune prédiction, aucun modèle :
seuls l'identité, le catalogue de compétitions, le plan de couverture et le quota fournisseur
sont exposés. Les cotes et les Value Bets arrivent en phases 3 à 5.

Aucune clé de fournisseur ne transite par cette API.
"""


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    configure_logging()
    STARTED_AT["at"] = time.time()
    app.state.lockout = await _build_lockout()

    init_engine()
    if settings.environment in ("dev", "test"):
        # Confort local uniquement : en staging/prod, `alembic upgrade head` est obligatoire.
        await create_all()
        logger.info("schéma vérifié (dev)")
    # Amorce idempotente du catalogue par défaut.
    from app.db.session import session_scope
    from app.ingestion.seed import ensure_default_competitions
    async with session_scope() as session:
        await ensure_default_competitions(session)
        await session.commit()
    logger.info("démarrage", extra={"extra_fields": {"environment": settings.environment}})
    try:
        yield
    finally:
        await dispose_engine()
        logger.info("arrêt propre")


async def _build_lockout():
    if not settings.redis_url:
        return InMemoryLockout()
    try:
        import redis.asyncio as redis

        client = redis.from_url(settings.redis_url, decode_responses=True)
        await client.ping()
        logger.info("verrouillage adossé à Redis")
        return RedisLockout(client)
    except Exception as exc:  # pragma: no cover - dépend de l'infrastructure
        logger.warning("Redis indisponible (%s) : verrouillage en mémoire", exc)
        return InMemoryLockout()


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.app_name,
        version=__version__,
        description=DESCRIPTION,
        lifespan=lifespan,
        docs_url="/docs" if settings.docs_enabled else None,
        redoc_url=None,
        openapi_url="/openapi.json" if settings.docs_enabled else None,
        contact={"name": "FOOTBALL VALUE AI", "url": "https://footballvalue.ai"},
        license_info={"name": "Propriétaire"},
    )
    install_middlewares(app)
    register_error_handlers(app)
    app.include_router(api_router, prefix=settings.api_prefix)
    return app


app = create_app()
