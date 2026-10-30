"""Middlewares transverses : identifiant de requête, en-têtes de sécurité, CORS."""

from __future__ import annotations

import time

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.middleware.cors import CORSMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.core.config import settings
from app.core.ids import new_id
from app.core.logging import set_request_id


class RequestContextMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = request.headers.get("X-Request-ID") or new_id("req")
        request.state.request_id = request_id
        set_request_id(request_id)

        started = time.perf_counter()
        response = await call_next(request)
        duration_ms = (time.perf_counter() - started) * 1000

        response.headers["X-Request-ID"] = request_id
        response.headers["X-API-Version"] = settings.api_version
        response.headers["X-Response-Time-ms"] = f"{duration_ms:.1f}"
        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("Referrer-Policy", "no-referrer")
        response.headers.setdefault("Cache-Control", "no-store")
        if settings.is_production:
            response.headers.setdefault(
                "Strict-Transport-Security", "max-age=31536000; includeSubDomains"
            )
        return response


def install_middlewares(app) -> None:
    app.add_middleware(RequestContextMiddleware)
    if settings.cors_origins:
        # Aucune version Web : le CORS ne sert qu'aux outils d'administration locaux.
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origins,
            allow_credentials=False,
            allow_methods=["GET", "POST", "PATCH", "DELETE"],
            allow_headers=["Authorization", "Content-Type", "X-Request-ID", "Idempotency-Key"],
            max_age=600,
        )
