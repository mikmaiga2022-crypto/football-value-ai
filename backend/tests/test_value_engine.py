"""Vecteurs normatifs T1, T2, T3 de `docs/07`."""

from __future__ import annotations

import pytest

from app.domain.value.engine import (
    DataQualityInput,
    MarketQuote,
    MarketThresholds,
    SelectionInput,
    devig,
    devig_shin,
    ev_interval,
    expected_value,
    fair_odds,
    kelly_fraction,
    score_selection,
)


def test_t1_ev_and_edge() -> None:
    assert expected_value(0.58, 1.95) == pytest.approx(0.131, abs=1e-9)
    assert fair_odds(0.58) == pytest.approx(1.724137, abs=1e-6)
    assert pytest.approx(0.08) == 0.58 - 0.50


def test_t1_two_way_market() -> None:
    market = MarketQuote((1.95, 1.95))
    assert market.overround == pytest.approx(1.025641, abs=1e-6)
    assert market.margin == pytest.approx(0.025641, abs=1e-6)
    assert market.devig()[0] == pytest.approx(0.5, abs=1e-9)


def test_t2_three_way_proportional() -> None:
    market = MarketQuote((2.10, 3.40, 3.60))
    assert market.margin == pytest.approx(0.048086, abs=1e-6)
    probs = market.devig("proportional")
    assert probs[0] == pytest.approx(0.454345, abs=1e-5)
    assert probs[1] == pytest.approx(0.280624, abs=1e-5)
    assert probs[2] == pytest.approx(0.265031, abs=1e-5)
    assert sum(probs) == pytest.approx(1.0, abs=1e-9)


@pytest.mark.parametrize("method", ["proportional", "additive", "power", "shin"])
def test_all_devig_methods_sum_to_one(method: str) -> None:
    probs = devig((2.10, 3.40, 3.60), method=method)  # type: ignore[arg-type]
    assert sum(probs) == pytest.approx(1.0, abs=1e-6)
    assert all(0.0 < p < 1.0 for p in probs)


def test_shin_keeps_ordering() -> None:
    probs = devig_shin((2.10, 3.40, 3.60))
    assert probs[0] > probs[1] > probs[2]


def test_ev_interval() -> None:
    low, high = ev_interval(0.545, 0.614, 1.95)
    assert low == pytest.approx(0.06275, abs=1e-6)
    assert high == pytest.approx(0.1973, abs=1e-6)


def test_kelly_never_negative() -> None:
    assert kelly_fraction(0.45, 1.95) == 0.0
    assert kelly_fraction(0.58, 1.95) == pytest.approx(0.1379, abs=1e-4)


def test_data_quality_score() -> None:
    rich = DataQualityInput(
        matches_played_home=30,
        matches_played_away=28,
        xg_available="both",
        lineup="official",
        injuries_complete_fresh=True,
        bookmakers_count=5,
        odds_age_seconds=30,
    )
    assert rich.score() == pytest.approx(1.0, abs=1e-9)

    poor = DataQualityInput(matches_played_home=0, matches_played_away=0, odds_age_seconds=1200)
    assert poor.score() == pytest.approx(0.0, abs=1e-9)


def test_t3_priority_a() -> None:
    """`docs/07` §6.4 : p=0,58, p⁻=0,545, p⁺=0,614, o=1,95, π=0,50, DQ=0,86, ECE=0,028."""
    result = score_selection(
        SelectionInput(
            odds=1.95,
            probability=0.58,
            probability_low=0.545,
            probability_high=0.614,
            market_probability=0.50,
            data_quality=0.86,
            market_margin=0.0256,
            is_verified=True,
            calibration_ece=0.028,
            roi_shrunk=0.02,
            odds_age_seconds=42,
            market_sample_size=400,
        )
    )
    assert result.score == pytest.approx(76.08, abs=0.05)
    assert result.priority == "A"
    assert result.ev == pytest.approx(0.131, abs=1e-9)
    assert result.explanation["conf_n"] == pytest.approx(0.655, abs=1e-3)


def test_gate_g8_lower_bound_blocks_priority_a() -> None:
    result = score_selection(
        SelectionInput(
            odds=1.95,
            probability=0.58,
            probability_low=0.50,
            probability_high=0.66,
            market_probability=0.50,
            data_quality=0.90,
            market_margin=0.0256,
            is_verified=True,
            calibration_ece=0.02,
            roi_shrunk=0.05,
            odds_age_seconds=30,
        )
    )
    assert result.ev > 0
    assert result.ev_lower < 0
    assert result.priority == "NO_BET"


def test_gate_g1_stale_odds() -> None:
    result = score_selection(
        SelectionInput(
            odds=1.95,
            probability=0.58,
            probability_low=0.55,
            probability_high=0.61,
            market_probability=0.50,
            data_quality=0.9,
            market_margin=0.02,
            is_verified=True,
            odds_age_seconds=5000,
        )
    )
    assert result.priority == "NO_BET"
    assert "G1_freshness" in result.caps


def test_gate_g5_poor_data() -> None:
    result = score_selection(
        SelectionInput(
            odds=1.95,
            probability=0.58,
            probability_low=0.55,
            probability_high=0.61,
            market_probability=0.50,
            data_quality=0.30,
            market_margin=0.02,
            is_verified=True,
        )
    )
    assert result.priority == "NO_BET"
    assert "G5_data_quality" in result.caps


def test_gate_g4_margin() -> None:
    thresholds = MarketThresholds(max_margin=0.05)
    result = score_selection(
        SelectionInput(
            odds=1.95,
            probability=0.58,
            probability_low=0.55,
            probability_high=0.61,
            market_probability=0.50,
            data_quality=0.9,
            market_margin=0.09,
            is_verified=True,
            thresholds=thresholds,
        )
    )
    assert result.priority == "NO_BET"


def test_unverified_caps_at_c() -> None:
    result = score_selection(
        SelectionInput(
            odds=1.95,
            probability=0.58,
            probability_low=0.545,
            probability_high=0.614,
            market_probability=0.50,
            data_quality=0.90,
            market_margin=0.0256,
            is_verified=False,
            calibration_ece=0.02,
            roi_shrunk=0.05,
            odds_age_seconds=30,
        )
    )
    assert result.priority in {"C", "D"}


def test_manual_bookmaker_caps_at_c() -> None:
    result = score_selection(
        SelectionInput(
            odds=2.10,
            probability=0.55,
            probability_low=0.53,
            probability_high=0.57,
            market_probability=0.47,
            data_quality=0.86,
            market_margin=0.03,
            is_verified=True,
            bookmaker_manual=True,
            odds_age_seconds=30,
        )
    )
    assert result.priority in {"C", "D"}


def test_invalid_inputs_rejected() -> None:
    with pytest.raises(ValueError):
        MarketQuote((1.0, 2.0))
    with pytest.raises(ValueError):
        fair_odds(1.0)
