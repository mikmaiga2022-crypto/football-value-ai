"""Agrégation des routes v1."""

from __future__ import annotations

from fastapi import APIRouter

from app.api.v1.routes import (
    admin_sync,
    auth,
    competitions,
    matches,
    meta,
    predictions,
    simulation,
    system,
    value,
)

api_router = APIRouter()
api_router.include_router(meta.router)
api_router.include_router(auth.router)
api_router.include_router(competitions.router)
api_router.include_router(matches.router)
api_router.include_router(predictions.router)
api_router.include_router(value.router)
api_router.include_router(admin_sync.router)
api_router.include_router(simulation.router)
api_router.include_router(system.router)

__all__ = ["api_router"]
