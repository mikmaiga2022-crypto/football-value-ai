"""Gouverneur de quota fournisseur (docs/09 §3.3).

Règle non négociable : **arrêt dur**. Quand le budget mensuel est atteint, plus aucun appel
automatique n'est autorisé ; l'application bascule en saisie manuelle et l'affiche.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.time import period_day, utcnow
from app.db.models import ApiQuotaLedger


class QuotaExceeded(Exception):
    def __init__(self, provider: str, requested: int, remaining: int) -> None:
        super().__init__(
            f"quota {provider} insuffisant : {requested} demandé(s), {remaining} restant(s)"
        )
        self.provider = provider
        self.requested = requested
        self.remaining = remaining


@dataclass(frozen=True)
class QuotaStatus:
    provider: str
    day: date
    used_today: int
    used_month: int
    monthly_budget: int
    monthly_limit: int
    remaining: int
    exhausted: bool
    degraded_reason: str | None


def _month_bounds(reference: date) -> tuple[date, date]:
    start = reference.replace(day=1)
    next_month = (start.replace(day=28) + timedelta(days=4)).replace(day=1)
    return start, next_month


class QuotaService:
    """Compteur persistant, un enregistrement par fournisseur et par jour."""

    def __init__(self, session: AsyncSession, *, provider: str = "the_odds_api") -> None:
        self.session = session
        self.provider = provider

    async def _month_used(self, reference: date) -> int:
        start, end = _month_bounds(reference)
        result = await self.session.execute(
            select(func.coalesce(func.sum(ApiQuotaLedger.credits_used), 0)).where(
                ApiQuotaLedger.provider == self.provider,
                ApiQuotaLedger.day >= start,
                ApiQuotaLedger.day < end,
            )
        )
        return int(result.scalar_one() or 0)

    async def _today_row(self, day: date) -> ApiQuotaLedger | None:
        result = await self.session.execute(
            select(ApiQuotaLedger).where(
                ApiQuotaLedger.provider == self.provider, ApiQuotaLedger.day == day
            )
        )
        return result.scalar_one_or_none()

    async def status(self) -> QuotaStatus:
        day = period_day()
        used_month = await self._month_used(day)
        row = await self._today_row(day)
        remaining = max(0, settings.odds_monthly_credit_budget - used_month)
        exhausted = remaining <= 0
        return QuotaStatus(
            provider=self.provider,
            day=day,
            used_today=row.credits_used if row else 0,
            used_month=used_month,
            monthly_budget=settings.odds_monthly_credit_budget,
            monthly_limit=settings.odds_provider_hard_limit,
            remaining=remaining,
            exhausted=exhausted,
            degraded_reason=(
                "Quota de cotes automatiques épuisé : saisie manuelle uniquement."
                if exhausted
                else None
            ),
        )

    async def can_spend(self, credits: int) -> bool:
        if credits <= 0:
            return True
        return (await self.status()).remaining >= credits

    async def spend(self, credits: int, note: str | None = None) -> QuotaStatus:
        """Réserve puis consomme `credits`. Lève `QuotaExceeded` avant tout appel réseau."""
        if credits <= 0:
            return await self.status()
        current = await self.status()
        if current.remaining < credits:
            raise QuotaExceeded(self.provider, credits, current.remaining)

        day = period_day()
        row = await self._today_row(day)
        if row is None:
            row = ApiQuotaLedger(provider=self.provider, day=day, credits_used=0)
            self.session.add(row)
        row.credits_used += credits
        row.updated_at = utcnow()
        if note:
            row.note = note[:120]
        await self.session.flush()
        return await self.status()
