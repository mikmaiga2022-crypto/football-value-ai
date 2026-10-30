"""Moteur statistique de base (Phase 4) : Elo + Poisson, sans ML."""

from __future__ import annotations

import hashlib
import json
import math
from dataclasses import dataclass


@dataclass(frozen=True)
class MatchProbabilities:
    home_win: float
    draw: float
    away_win: float
    over_2_5: float
    under_2_5: float
    btts_yes: float
    lambda_home: float
    lambda_away: float


def _poisson_pmf(lam: float, k: int) -> float:
    return math.exp(-lam) * (lam**k) / math.factorial(k)


def compute_probabilities(home_elo: float, away_elo: float) -> MatchProbabilities:
    diff = home_elo - away_elo
    lam_home = 1.35 * math.exp(diff / 1500.0)
    lam_away = 1.35 * math.exp(-diff / 1500.0)
    lam_home = min(4.0, max(0.3, lam_home))
    lam_away = min(4.0, max(0.3, lam_away))

    matrix: list[list[float]] = []
    max_goals = 8
    for i in range(max_goals + 1):
        row = []
        for j in range(max_goals + 1):
            row.append(_poisson_pmf(lam_home, i) * _poisson_pmf(lam_away, j))
        matrix.append(row)

    total = sum(matrix[i][j] for i in range(max_goals + 1) for j in range(max_goals + 1))
    home_win = sum(matrix[i][j] for i in range(max_goals + 1) for j in range(i)) / total
    draw = sum(matrix[i][i] for i in range(max_goals + 1)) / total
    away_win = (
        sum(matrix[i][j] for i in range(max_goals + 1) for j in range(i + 1, max_goals + 1)) / total
    )
    over = (
        sum(matrix[i][j] for i in range(max_goals + 1) for j in range(max_goals + 1) if i + j > 2.5)
        / total
    )
    under = 1.0 - over
    btts = (
        sum(matrix[i][j] for i in range(1, max_goals + 1) for j in range(1, max_goals + 1)) / total
    )

    return MatchProbabilities(
        home_win=home_win,
        draw=draw,
        away_win=away_win,
        over_2_5=over,
        under_2_5=under,
        btts_yes=btts,
        lambda_home=lam_home,
        lambda_away=lam_away,
    )


def features_hash(payload: dict) -> str:
    canonical = json.dumps(payload, sort_keys=True, default=str)
    return hashlib.sha256(canonical.encode()).hexdigest()


def row_hash(payload: dict, prev_hash: str | None) -> str:
    canonical = json.dumps(payload, sort_keys=True, default=str)
    return hashlib.sha256((canonical + (prev_hash or "")).encode()).hexdigest()


def update_elo(
    home_elo: float, away_elo: float, home_goals: int, away_goals: int, k: float = 20.0
) -> tuple[float, float]:
    expected_home = 1.0 / (1.0 + 10 ** ((away_elo - home_elo) / 400.0))
    expected_away = 1.0 - expected_home
    if home_goals > away_goals:
        score_home, score_away = 1.0, 0.0
    elif home_goals < away_goals:
        score_home, score_away = 0.0, 1.0
    else:
        score_home, score_away = 0.5, 0.5
    new_home = home_elo + k * (score_home - expected_home)
    new_away = away_elo + k * (score_away - expected_away)
    return new_home, new_away
