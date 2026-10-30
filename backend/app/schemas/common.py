"""Enveloppes et types communs de réponse (docs/04 §1 et §4)."""

from __future__ import annotations

from typing import Generic, TypeVar

from pydantic import BaseModel, Field

DataT = TypeVar("DataT")


class Meta(BaseModel):
    server_time: str = Field(description="Horodatage serveur ISO 8601 UTC")
    api_version: str
    degraded: bool = Field(
        default=False, description="Mode réduit (quota, fournisseur indisponible)"
    )
    degraded_reason: str | None = None
    freshness_seconds: int | None = Field(
        default=None, description="Âge de la donnée la plus ancienne affichée"
    )


class Envelope(BaseModel, Generic[DataT]):
    data: DataT
    meta: Meta


class ErrorDetail(BaseModel):
    code: str
    message: str
    details: dict = Field(default_factory=dict)
    request_id: str


class ErrorEnvelope(BaseModel):
    error: ErrorDetail


class Pagination(BaseModel):
    next_cursor: str | None = None
    has_more: bool = False
    limit: int


class Page(BaseModel, Generic[DataT]):
    data: list[DataT]
    pagination: Pagination
    meta: Meta
