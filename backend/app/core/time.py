"""Horloge et formats temporels.

Toutes les dates sont stockées et servies en UTC, sérialisées en ISO 8601 avec suffixe `Z`
(docs/04 §1). Aucune date locale n'est persistée.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta


def utcnow() -> datetime:
    return datetime.now(UTC)


def iso_z(value: datetime) -> str:
    """`2026-10-31T17:30:00Z` — jamais de décalage implicite."""
    if value.tzinfo is None:
        raise ValueError("une date naïve ne peut pas être sérialisée")
    return value.astimezone(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")


def server_time() -> str:
    return iso_z(utcnow())


def add_seconds(value: datetime, seconds: int) -> datetime:
    return value + timedelta(seconds=seconds)


def as_utc(value: datetime) -> datetime:
    """SQLite renvoie des dates naïves : on les interprète comme UTC (stockage normalisé)."""
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def add_days(value: datetime, days: int) -> datetime:
    return value + timedelta(days=days)


def period_day(value: datetime | None = None) -> date:
    return (value or utcnow()).astimezone(UTC).date()
