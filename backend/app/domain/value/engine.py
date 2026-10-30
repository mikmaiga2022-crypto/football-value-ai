"""Moteur de Value Betting — fonctions pures, sans dépendance framework.

Conforme à `docs/07` (formules normatives). Ces fonctions sont testées sur les vecteurs
T1, T2 et T3 documentés ; toute modification doit mettre à jour la spécification.
"""

from __future__ import annotations

from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from decimal import Decimal
from typing import Literal

EPS = 1e-12
#: Nombre maximal d'itérations des résolutions numériques (docs/07 §2.2).
MAX_ITERATIONS = 200
#: Tolérance des résolutions numériques.
TOLERANCE = 1e-10

DevigMethod = Literal["proportional", "additive", "power", "shin"]
Priority = Literal["A", "B", "C", "D", "NO_BET"]


# --- Marge et probabilités sans marge -------------------------------------


@dataclass(frozen=True)
class MarketQuote:
    """Cotes d'un marché à issues exhaustives (ex. 1X2, O/U 2,5)."""

    odds: tuple[float, ...]

    def __post_init__(self) -> None:
        if len(self.odds) < 2:
            raise ValueError("un marché exige au moins deux issues")
        for odd in self.odds:
            if not odd > 1.0:
                raise ValueError(f"cote invalide : {odd} (doit être > 1.00)")

    @property
    def implied(self) -> tuple[float, ...]:
        return tuple(1.0 / odd for odd in self.odds)

    @property
    def overround(self) -> float:
        """`S = Σ q_i`."""
        return sum(self.implied)

    @property
    def margin(self) -> float:
        """`m = S − 1`."""
        return self.overround - 1.0

    def devig(self, method: DevigMethod = "proportional") -> tuple[float, ...]:
        return devig(self.odds, method=method)


def devig_proportional(odds: Sequence[float]) -> tuple[float, ...]:
    implied = [1.0 / odd for odd in odds]
    total = sum(implied)
    return tuple(q / total for q in implied)


def devig_additive(odds: Sequence[float]) -> tuple[float, ...]:
    implied = [1.0 / odd for odd in odds]
    margin = sum(implied) - 1.0
    share = margin / len(implied)
    return tuple(q - share for q in implied)


def devig_power(odds: Sequence[float]) -> tuple[float, ...]:
    """`π_i = q_i^k` avec `k` tel que `Σ q_i^k = 1` (bissection sur k)."""
    implied = [1.0 / odd for odd in odds]
    if abs(sum(implied) - 1.0) < TOLERANCE:
        return tuple(implied)

    def total(k: float) -> float:
        return sum(q**k for q in implied)

    low, high = 0.5, 2.0
    # Le signe de (total(k) − 1) dépend du sens de la marge : on encadre la racine.
    for _ in range(60):
        if total(low) - 1.0 > 0:
            low /= 2
        else:
            break
    for _ in range(60):
        if total(high) - 1.0 < 0:
            high *= 2
        else:
            break

    for _ in range(MAX_ITERATIONS):
        mid = (low + high) / 2
        if total(mid) > 1.0:
            low = mid
        else:
            high = mid
        if abs(total(mid) - 1.0) < TOLERANCE:
            break
    k = (low + high) / 2
    result = tuple(q**k for q in implied)
    return result


def devig_shin(odds: Sequence[float]) -> tuple[float, ...]:
    """Modèle de Shin : `π_i = (√(z² + 4(1−z) q_i²/S) − z) / (2(1−z))`, `z` tel que `Σ π_i = 1`."""
    implied = [1.0 / odd for odd in odds]
    total = sum(implied)
    if abs(total - 1.0) < TOLERANCE:
        return tuple(implied)

    def probs(z: float) -> tuple[float, ...]:
        if z <= 0.0:
            return tuple(q / total for q in implied)
        if z >= 1.0:
            z = 1.0 - EPS
        denominator = 2.0 * (1.0 - z)
        out = []
        for q in implied:
            inner = z * z + 4.0 * (1.0 - z) * (q * q) / total
            out.append(((inner**0.5) - z) / denominator)
        return tuple(out)

    low, high = 0.0, 0.999999
    for _ in range(MAX_ITERATIONS):
        mid = (low + high) / 2
        diff = sum(probs(mid)) - 1.0
        if abs(diff) < TOLERANCE:
            break
        # Σ π(z) est décroissante en z.
        if diff > 0:
            low = mid
        else:
            high = mid
    return probs((low + high) / 2)


def devig(odds: Sequence[float], method: DevigMethod = "proportional") -> tuple[float, ...]:
    if method == "proportional":
        return devig_proportional(odds)
    if method == "additive":
        return devig_additive(odds)
    if method == "power":
        return devig_power(odds)
    if method == "shin":
        return devig_shin(odds)
    raise ValueError(f"méthode de retrait de marge inconnue : {method}")


# --- Cote juste, edge, EV --------------------------------------------------


def fair_odds(probability: float) -> float:
    if not 0.0 < probability < 1.0:
        raise ValueError("la probabilité doit être dans ]0, 1[")
    return 1.0 / probability


def expected_value(probability: float, odds: float) -> float:
    """`EV = p · o − 1`."""
    return probability * odds - 1.0


def edge(probability: float, market_probability: float) -> float:
    """`e = p − π`."""
    return probability - market_probability


def ev_interval(
    probability_low: float, probability_high: float, odds: float
) -> tuple[float, float]:
    return (probability_low * odds - 1.0, probability_high * odds - 1.0)


def kelly_fraction(probability: float, odds: float) -> float:
    """Part de bankroll de Kelly, bornée à [0, 1] ; 0 si EV ≤ 0."""
    if odds <= 1.0:
        raise ValueError("cote invalide")
    b = odds - 1.0
    fraction = (probability * odds - 1.0) / b
    return max(0.0, min(1.0, fraction))


# --- Qualité des données --------------------------------------------------

DQ_WEIGHTS_V1: dict[str, float] = {
    "history": 0.25,
    "advanced_stats": 0.15,
    "lineup": 0.15,
    "injuries": 0.10,
    "odds_coverage": 0.20,
    "freshness": 0.15,
}


@dataclass(frozen=True)
class DataQualityInput:
    matches_played_home: int
    matches_played_away: int
    xg_available: Literal["both", "one", "none"] = "none"
    lineup: Literal["official", "probable", "none"] = "none"
    injuries_complete_fresh: bool = False
    bookmakers_count: int = 0
    odds_age_seconds: float = 0.0
    max_age_seconds: float = 900.0

    def components(self) -> dict[str, float]:
        history = (
            min(1.0, self.matches_played_home / 20.0) + min(1.0, self.matches_played_away / 20.0)
        ) / 2.0
        advanced = {"both": 1.0, "one": 0.5, "none": 0.0}[self.xg_available]
        lineup = {"official": 1.0, "probable": 0.6, "none": 0.0}[self.lineup]
        injuries = 1.0 if self.injuries_complete_fresh else 0.0
        coverage = min(1.0, self.bookmakers_count / 3.0)
        if self.odds_age_seconds <= 60:
            freshness = 1.0
        elif self.odds_age_seconds >= self.max_age_seconds:
            freshness = 0.0
        else:
            span = self.max_age_seconds - 60.0
            freshness = max(0.0, 1.0 - (self.odds_age_seconds - 60.0) / span)
        return {
            "history": history,
            "advanced_stats": advanced,
            "lineup": lineup,
            "injuries": injuries,
            "odds_coverage": coverage,
            "freshness": freshness,
        }

    def score(self) -> float:
        comps = self.components()
        return sum(comps[name] * weight for name, weight in DQ_WEIGHTS_V1.items())


# --- Seuils par marché -----------------------------------------------------


@dataclass(frozen=True)
class MarketThresholds:
    """Seuils validés par marché ; valeurs par défaut = prudentes (docs/07 §6)."""

    min_ev: float = 0.03
    min_ev_lower: float = 0.005
    max_margin: float = 0.08
    min_odds: float = 1.30
    max_odds: float = 6.00
    max_age_seconds: float = 900.0


@dataclass(frozen=True)
class SelectionInput:
    odds: float
    probability: float
    probability_low: float
    probability_high: float
    market_probability: float
    data_quality: float
    market_margin: float
    is_verified: bool
    bookmaker_manual: bool = False
    calibration_ece: float = 0.03
    roi_shrunk: float = 0.0
    odds_age_seconds: float = 0.0
    market_sample_size: int = 500
    bookmaker_accessible: bool = True
    lineup_known: bool = True
    thresholds: MarketThresholds = MarketThresholds()


@dataclass(frozen=True)
class SelectionScore:
    score: float
    priority: Priority
    ev: float
    ev_lower: float
    edge: float
    fair_odds: float
    caps: tuple[str, ...]
    penalties: tuple[str, ...]
    explanation: dict[str, float | str]


def _clamp(value: float) -> float:
    return max(0.0, min(1.0, value))


def score_selection(item: SelectionInput) -> SelectionScore:
    """Applique les gates G1–G10 puis le score continu (docs/07 §6)."""
    t = item.thresholds
    ev = expected_value(item.probability, item.odds)
    ev_lower, _ = ev_interval(item.probability_low, item.probability_high, item.odds)
    market_edge = edge(item.probability, item.market_probability)
    caps: list[str] = []
    penalties: list[str] = []

    # Gates éliminatoires.
    if item.odds_age_seconds > t.max_age_seconds:
        return SelectionScore(
            0.0,
            "NO_BET",
            ev,
            ev_lower,
            market_edge,
            fair_odds(item.probability),
            ("G1_freshness",),
            (),
            {"reason": "stale_odds"},
        )
    if item.market_margin > t.max_margin:
        return SelectionScore(
            0.0,
            "NO_BET",
            ev,
            ev_lower,
            market_edge,
            fair_odds(item.probability),
            ("G4_margin",),
            (),
            {"reason": "margin_too_high"},
        )
    if not (t.min_odds <= item.odds <= t.max_odds):
        return SelectionScore(
            0.0,
            "NO_BET",
            ev,
            ev_lower,
            market_edge,
            fair_odds(item.probability),
            ("G6_odds_bounds",),
            (),
            {"reason": "odds_out_of_bounds"},
        )
    if item.data_quality < 0.45:
        return SelectionScore(
            0.0,
            "NO_BET",
            ev,
            ev_lower,
            market_edge,
            fair_odds(item.probability),
            ("G5_data_quality",),
            (),
            {"reason": "insufficient_data"},
        )
    if ev < t.min_ev:
        return SelectionScore(
            0.0,
            "NO_BET",
            ev,
            ev_lower,
            market_edge,
            fair_odds(item.probability),
            ("G7_ev",),
            (),
            {"reason": "ev_below_threshold"},
        )

    # Plafonds.
    if not item.is_verified:
        caps.append("G2_unverified")
        penalties.append("unverified_odds")
    if not item.bookmaker_accessible:
        penalties.append("bookmaker_unavailable")
    if item.calibration_ece > 0.08:
        caps.append("G9_calibration")
    if item.bookmaker_manual:
        caps.append("G10_manual_bookmaker")
    if ev_lower < t.min_ev_lower:
        caps.append("G8_ev_lower")
    if item.odds_age_seconds > 0.6 * t.max_age_seconds:
        penalties.append("aging_odds")
    if not item.lineup_known:
        penalties.append("lineup_unknown")
    if item.market_sample_size < 50:
        penalties.append("small_sample")

    ev_n = _clamp(ev / 0.15)
    edge_n = _clamp(market_edge / 0.10)
    conf_n = 1.0 - _clamp((item.probability_high - item.probability_low) / 0.20)
    calib_n = 1.0 - _clamp(item.calibration_ece / 0.10)
    dq_n = item.data_quality
    hist_n = _clamp((item.roi_shrunk + 0.05) / 0.15)

    raw = 100.0 * (
        0.28 * ev_n + 0.18 * edge_n + 0.20 * conf_n + 0.14 * calib_n + 0.12 * dq_n + 0.08 * hist_n
    )

    penalty_points = 0.0
    if "unverified_odds" in penalties:
        penalty_points += 25.0
    if "aging_odds" in penalties:
        penalty_points += 10.0
    if "lineup_unknown" in penalties:
        penalty_points += 5.0
    if "bookmaker_unavailable" in penalties:
        penalty_points += 15.0
    if "small_sample" in penalties:
        penalty_points += 10.0

    score = max(0.0, raw - penalty_points)
    priority = _grade(score, ev, ev_lower, item.data_quality, item.is_verified, caps)
    return SelectionScore(
        score=round(score, 2),
        priority=priority,
        ev=ev,
        ev_lower=ev_lower,
        edge=market_edge,
        fair_odds=fair_odds(item.probability),
        caps=tuple(caps),
        penalties=tuple(penalties),
        explanation={
            "ev": round(ev, 6),
            "ev_lower": round(ev_lower, 6),
            "edge": round(market_edge, 6),
            "ev_n": round(ev_n, 4),
            "edge_n": round(edge_n, 4),
            "conf_n": round(conf_n, 4),
            "calib_n": round(calib_n, 4),
            "dq_n": round(dq_n, 4),
            "hist_n": round(hist_n, 4),
            "penalty_points": penalty_points,
        },
    )


def _grade(
    score: float,
    ev: float,
    ev_lower: float,
    data_quality: float,
    is_verified: bool,
    caps: Iterable[str],
) -> Priority:
    cap_set = set(caps)
    if ev_lower <= 0.0 or "G8_ev_lower" in cap_set:
        return "NO_BET"
    if not is_verified:
        return "C" if score >= 48 else "D" if score >= 30 else "NO_BET"
    if "G9_calibration" in cap_set or "G10_manual_bookmaker" in cap_set:
        return "C" if score >= 48 else "D" if score >= 30 else "NO_BET"
    if score >= 75 and ev > 0.0 and ev_lower > 0.0 and data_quality >= 0.75:
        return "A"
    if score >= 62:
        return "B"
    if score >= 48:
        return "C"
    if score >= 30:
        return "D"
    return "NO_BET"


def to_decimal(value: float, places: int = 6) -> Decimal:
    """Conversion explicite pour la persistance (jamais de float pour un montant)."""
    return Decimal(f"{value:.{places}f}")
