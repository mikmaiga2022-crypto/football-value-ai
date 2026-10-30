"""Plan de couverture des compétitions sous contrainte de quota (docs/09 §3.2–3.3).

Fonctions pures : aucun accès base, aucun réseau. Le résultat est persisté par un job.

Principe : le catalogue peut contenir toutes les compétitions, mais seules celles qui
tiennent dans le budget de crédits sont « servies » automatiquement. Les autres restent
visibles en catalogue, sans cote automatique — jamais avec une donnée inventée.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass, replace
from typing import Literal

CoverageState = Literal["served", "opportunistic", "catalog", "disabled"]


@dataclass(frozen=True)
class CompetitionRef:
    code: str
    name: str
    tier: int = 3
    demand_score: int = 0
    is_international: bool = False
    is_active: bool = True


@dataclass(frozen=True)
class CoveragePolicy:
    """Paramètres issus de `docs/09` §3.3. Toute modification doit être justifiée."""

    served_slots: int = 3
    opportunistic_slots: int = 2
    batches_per_served_day: int = 2
    priority_refresh_slots: int = 2
    on_demand_monthly_credits: int = 30
    monthly_budget_credits: int = 270
    days_per_month: int = 30

    def cost(self, served: int, opportunistic: int, priority: int) -> int:
        """Crédits mensuels d'un plan : batchs + rafraîchissement prioritaire + à la demande."""
        del opportunistic  # les opportunistes ne coûtent rien tant qu'aucun utilisateur ne demande
        batches = served * self.batches_per_served_day * self.days_per_month
        refresh = priority * self.days_per_month
        return batches + refresh + self.on_demand_monthly_credits


@dataclass(frozen=True)
class CoverageAssignment:
    code: str
    state: CoverageState
    reason: str


@dataclass(frozen=True)
class CoveragePlan:
    assignments: tuple[CoverageAssignment, ...]
    monthly_credits: int
    monthly_budget: int
    headroom: int
    degraded: bool
    notes: tuple[str, ...]

    def by_state(self, state: CoverageState) -> tuple[str, ...]:
        return tuple(a.code for a in self.assignments if a.state == state)


def _rank(competition: CompetitionRef) -> tuple[int, int, int, str]:
    # Demande d'abord, puis prestige (tier faible = mieux), puis international, puis code.
    return (
        -competition.demand_score,
        competition.tier,
        0 if competition.is_international else 1,
        competition.code,
    )


def plan_coverage(
    competitions: Sequence[CompetitionRef],
    policy: CoveragePolicy | None = None,
) -> CoveragePlan:
    policy = policy or CoveragePolicy()
    notes: list[str] = []

    active = [c for c in competitions if c.is_active]
    disabled = [c for c in competitions if not c.is_active]
    ordered = sorted(active, key=_rank)

    served = min(policy.served_slots, len(ordered))
    opportunistic = 0
    priority = 0

    def build(served_count: int, opportunistic_count: int, priority_count: int) -> CoveragePlan:
        assignments: list[CoverageAssignment] = []
        for index, competition in enumerate(ordered):
            if index < served_count:
                state: CoverageState = "served"
                reason = "dans le budget automatique"
            elif index < served_count + opportunistic_count:
                state = "opportunistic"
                reason = "cotes à la demande uniquement"
            else:
                state = "catalog"
                reason = "catalogue seul : quota de crédits épuisé"
            assignments.append(CoverageAssignment(competition.code, state, reason))
        for competition in disabled:
            assignments.append(
                CoverageAssignment(competition.code, "disabled", "compétition désactivée")
            )
        cost = policy.cost(served_count, opportunistic_count, priority_count)
        return CoveragePlan(
            assignments=tuple(assignments),
            monthly_credits=cost,
            monthly_budget=policy.monthly_budget_credits,
            headroom=policy.monthly_budget_credits - cost,
            degraded=cost > policy.monthly_budget_credits,
            notes=tuple(notes),
        )

    # Ajustement : on réduit le nombre de compétitions servies tant que le budget est dépassé.
    while served > 0:
        priority = min(policy.priority_refresh_slots, served)
        opportunistic = min(policy.opportunistic_slots, max(0, len(ordered) - served))
        plan = build(served, opportunistic, priority)
        if plan.monthly_credits <= policy.monthly_budget_credits:
            break
        served -= 1
        notes.append(f"budget insuffisant : passage à {served} compétition(s) servie(s)")

    if not ordered:
        notes.append("catalogue vide : aucune compétition à servir")
        return build(0, 0, 0)

    plan = build(
        served,
        min(policy.opportunistic_slots, max(0, len(ordered) - served)),
        min(policy.priority_refresh_slots, served),
    )
    if plan.headroom < 0:
        notes.append("plan dégradé : quota mensuel dépassé, arrêt dur requis")
    return replace(plan, notes=tuple(notes))
