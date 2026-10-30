"""Plan de couverture sous contrainte de quota (docs/09 §3)."""

from __future__ import annotations

from app.domain.coverage import CompetitionRef, CoveragePolicy, plan_coverage


def _catalogue() -> list[CompetitionRef]:
    return [
        CompetitionRef("EPL", "Premier League", tier=1, demand_score=100, is_international=True),
        CompetitionRef("L1", "Ligue 1", tier=1, demand_score=95, is_international=True),
        CompetitionRef(
            "CAN", "Coupe d'Afrique des Nations", tier=1, demand_score=90, is_international=True
        ),
        CompetitionRef("LIGA", "La Liga", tier=1, demand_score=80, is_international=True),
        CompetitionRef("SA", "Serie A", tier=1, demand_score=78, is_international=True),
        CompetitionRef("BL", "Bundesliga", tier=1, demand_score=76, is_international=True),
        CompetitionRef("FASO", "Fasofoot", tier=3, demand_score=60),
        CompetitionRef(
            "UCL", "Ligue des champions", tier=1, demand_score=88, is_international=True
        ),
    ]


def test_default_plan_respects_budget() -> None:
    plan = plan_coverage(_catalogue())
    assert plan.by_state("served") == ("EPL", "L1", "CAN")
    assert plan.by_state("opportunistic") == ("UCL", "LIGA")
    assert plan.monthly_credits == 270
    assert plan.monthly_budget == 270
    assert plan.headroom == 0
    assert plan.degraded is False


def test_cost_breakdown_matches_docs_09() -> None:
    policy = CoveragePolicy()
    assert policy.cost(3, 2, 2) == 3 * 2 * 30 + 2 * 30 + 30


def test_small_budget_reduces_served_competitions() -> None:
    plan = plan_coverage(_catalogue(), CoveragePolicy(monthly_budget_credits=150))
    assert plan.monthly_credits <= 150
    assert len(plan.by_state("served")) == 1
    assert any("budget insuffisant" in note for note in plan.notes)


def test_every_competition_is_assigned_once() -> None:
    catalogue = _catalogue()
    plan = plan_coverage(catalogue)
    assigned = [a.code for a in plan.assignments]
    assert sorted(assigned) == sorted(c.code for c in catalogue)
    assert len(set(assigned)) == len(assigned)


def test_disabled_competitions_are_marked() -> None:
    catalogue = _catalogue() + [CompetitionRef("OLD", "Compétition arrêtée", is_active=False)]
    plan = plan_coverage(catalogue)
    assert plan.by_state("disabled") == ("OLD",)


def test_empty_catalogue() -> None:
    plan = plan_coverage([])
    assert plan.assignments == ()
    assert any("catalogue vide" in note for note in plan.notes)


def test_ranking_prefers_demand_then_tier() -> None:
    catalogue = [
        CompetitionRef("LOW", "Petite compétition", tier=3, demand_score=10),
        CompetitionRef("HIGH", "Grande compétition", tier=1, demand_score=90),
        CompetitionRef("MID", "Moyenne", tier=2, demand_score=50),
    ]
    plan = plan_coverage(catalogue)
    assert plan.by_state("served")[0] == "HIGH"
    assert plan.by_state("served")[1] == "MID"
