"""Enveloppe d'erreur unique (docs/04 §4).

    {"error": {"code", "message", "details", "request_id"}}

Aucun message technique (trace, requête SQL) ne fuit vers le client.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.ids import new_id

logger = logging.getLogger("fva.errors")

_STATUS_CODES: dict[int, str] = {
    status.HTTP_400_BAD_REQUEST: "VALIDATION_ERROR",
    status.HTTP_401_UNAUTHORIZED: "UNAUTHENTICATED",
    status.HTTP_403_FORBIDDEN: "FORBIDDEN",
    status.HTTP_404_NOT_FOUND: "NOT_FOUND",
    status.HTTP_405_METHOD_NOT_ALLOWED: "METHOD_NOT_ALLOWED",
    status.HTTP_409_CONFLICT: "CONFLICT",
    422: "UNPROCESSABLE_CONTENT",
    status.HTTP_429_TOO_MANY_REQUESTS: "RATE_LIMITED",
    status.HTTP_503_SERVICE_UNAVAILABLE: "PROVIDER_UNAVAILABLE",
}


class ApiError(Exception):
    """Erreur métier explicite, traduite en enveloppe JSON."""

    def __init__(
        self,
        status_code: int,
        code: str,
        message: str,
        details: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
    ) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details or {}
        self.headers = headers or {}


def error_body(request: Request, code: str, message: str, details: dict[str, Any] | None) -> dict:
    request_id = getattr(request.state, "request_id", None) or new_id("req")
    return {
        "error": {
            "code": code,
            "message": message,
            "details": details or {},
            "request_id": request_id,
        }
    }


async def api_error_handler(request: Request, exc: ApiError) -> JSONResponse:
    headers = dict(exc.headers)
    if exc.status_code == status.HTTP_429_TOO_MANY_REQUESTS and "Retry-After" not in headers:
        headers["Retry-After"] = "60"
    return JSONResponse(
        status_code=exc.status_code,
        content=error_body(request, exc.code, exc.message, exc.details),
        headers=headers,
    )


async def validation_error_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    details = {
        "fields": [
            {
                "loc": [str(part) for part in err.get("loc", ())],
                "type": err.get("type", "invalid"),
                "msg": err.get("msg", "valeur invalide"),
            }
            for err in exc.errors()
        ]
    }
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content=error_body(request, "VALIDATION_ERROR", "Requête invalide.", details),
    )


async def http_error_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    code = _STATUS_CODES.get(exc.status_code, "HTTP_ERROR")
    detail = exc.detail if isinstance(exc.detail, str) else "Requête refusée."
    return JSONResponse(
        status_code=exc.status_code,
        content=error_body(request, code, detail, None),
        headers=dict(exc.headers or {}),
    )


async def unhandled_error_handler(request: Request, exc: Exception) -> JSONResponse:
    request_id = getattr(request.state, "request_id", "unknown")
    logger.exception("erreur non gérée", extra={"request_id": request_id, "path": request.url.path})
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=error_body(request, "INTERNAL_ERROR", "Erreur interne.", None),
    )


def register_error_handlers(app: FastAPI) -> None:
    app.add_exception_handler(ApiError, api_error_handler)  # type: ignore[arg-type]
    app.add_exception_handler(RequestValidationError, validation_error_handler)  # type: ignore[arg-type]
    app.add_exception_handler(StarletteHTTPException, http_error_handler)  # type: ignore[arg-type]
    app.add_exception_handler(Exception, unhandled_error_handler)
