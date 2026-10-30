"""Journalisation structurée JSON, sans donnée personnelle (docs/02 §9)."""

from __future__ import annotations

import json
import logging
import sys
from contextvars import ContextVar
from typing import Any

from app.core.config import settings

_request_id: ContextVar[str] = ContextVar("request_id", default="-")

_SENSITIVE_KEYS = {"password", "token", "access_token", "refresh_token", "authorization", "email"}


def set_request_id(value: str) -> None:
    _request_id.set(value)


def get_request_id() -> str:
    return _request_id.get()


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
            "request_id": get_request_id(),
        }
        for key, value in getattr(record, "extra_fields", {}).items():
            if key.lower() not in _SENSITIVE_KEYS:
                payload[key] = value
        if record.exc_info:
            payload["exc"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False)


def configure_logging() -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(settings.log_level.upper())
    for noisy in ("uvicorn.access", "sqlalchemy.engine"):
        logging.getLogger(noisy).setLevel(logging.WARNING)
