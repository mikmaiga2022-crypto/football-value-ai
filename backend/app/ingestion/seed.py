"""Données de référence minimales (compétitions servies par le pilote 0 €)."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Competition

DEFAULT_COMPETITIONS = [
    ("FR1", "Ligue 1", "FR", "UEFA", 1, "2026/2027"),
    ("EPL", "Premier League", "GB", "UEFA", 1, "2026/2027"),
    ("CAN", "CAN", "AF", "CAF", 1, "2026/2027"),
    ("ES1", "La Liga", "ES", "UEFA", 1, "2026/2027"),
]


async def ensure_default_competitions(session: AsyncSession) -> None:
    existing = set((await session.execute(select(Competition.code))).scalars().all())
    for code, name, country, confed, tier, season in DEFAULT_COMPETITIONS:
        if code not in existing:
            session.add(
                Competition(
                    code=code,
                    name=name,
                    country_code=country,
                    confederation=confed,
                    tier=tier,
                    season=season,
                    coverage_state="catalog",
                    demand_score=100 if code in {"FR1", "EPL", "CAN"} else 80,
                    is_active=True,
                )
            )
    await session.flush()
