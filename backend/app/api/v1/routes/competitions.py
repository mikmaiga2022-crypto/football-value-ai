"""Catalogue des compétitions."""

from __future__ import annotations

import base64
import binascii

from fastapi import APIRouter, Query
from sqlalchemy import func, or_, select

from app.api.deps import CurrentUser, DbSession, meta
from app.core.errors import ApiError
from app.db.models import Competition
from app.schemas.common import Page, Pagination
from app.schemas.competition import CompetitionOut

router = APIRouter(tags=["competitions"])

MAX_LIMIT = 50


def _encode_cursor(offset: int) -> str:
    return base64.urlsafe_b64encode(f"o:{offset}".encode()).decode().rstrip("=")


def _decode_cursor(cursor: str) -> int:
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        raw = base64.urlsafe_b64decode(padded.encode()).decode()
        prefix, _, value = raw.partition(":")
        if prefix != "o" or not value.isdigit():
            raise ValueError
        return int(value)
    except (ValueError, binascii.Error, UnicodeDecodeError) as exc:
        raise ApiError(400, "INVALID_CURSOR", "Curseur de pagination invalide.") from exc


@router.get("/competitions", response_model=Page[CompetitionOut], summary="Lister les compétitions")
async def list_competitions(
    session: DbSession,
    user: CurrentUser,
    state: str | None = Query(default=None, pattern="^(served|opportunistic|catalog|disabled)$"),
    q: str | None = Query(default=None, min_length=2, max_length=40),
    limit: int = Query(default=20, ge=1, le=MAX_LIMIT),
    cursor: str | None = None,
) -> Page[CompetitionOut]:
    del user  # la permission est vérifiée en amont si nécessaire
    offset = _decode_cursor(cursor) if cursor else 0

    stmt = select(Competition).where(Competition.is_active.is_(True))
    if state:
        stmt = stmt.where(Competition.coverage_state == state)
    if q:
        needle = f"%{q.strip().lower()}%"
        stmt = stmt.where(
            or_(
                func.lower(Competition.name).like(needle),
                func.lower(Competition.code).like(needle),
            )
        )

    rows = (
        (
            await session.execute(
                stmt.order_by(Competition.demand_score.desc(), Competition.name)
                .offset(offset)
                .limit(limit + 1)
            )
        )
        .scalars()
        .all()
    )

    has_more = len(rows) > limit
    page = rows[:limit]
    return Page(
        data=[CompetitionOut.model_validate(row) for row in page],
        pagination=Pagination(
            next_cursor=_encode_cursor(offset + limit) if has_more else None,
            has_more=has_more,
            limit=limit,
        ),
        meta=meta(),
    )


@router.get(
    "/competitions/{code}", response_model=CompetitionOut, summary="Détail d'une compétition"
)
async def get_competition(code: str, session: DbSession, user: CurrentUser) -> CompetitionOut:
    del user
    competition = await session.get(Competition, code.upper())
    if competition is None or not competition.is_active:
        raise ApiError(404, "NOT_FOUND", "Compétition inconnue.")
    return CompetitionOut.model_validate(competition)
