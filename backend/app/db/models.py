"""Modèles SQLAlchemy — sous-ensemble de la Phase 2.

Le DDL de référence complet (partitionnement, triggers d'immuabilité, prédictions) reste
`db/schema.sql`. Ici : identité, catalogue des compétitions, audit, quota fournisseur.
"""

from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import (
    JSON,
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import CODE, ID, SHORT, Base, TimestampMixin

# --- Utilisateurs ----------------------------------------------------------


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(ID, primary_key=True)
    email: Mapped[str] = mapped_column(String(320), unique=True, nullable=False, index=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    display_name: Mapped[str | None] = mapped_column(String(60))
    locale: Mapped[str] = mapped_column(String(8), default="fr", nullable=False)
    timezone: Mapped[str] = mapped_column(String(64), default="Africa/Ouagadougou", nullable=False)
    role: Mapped[str] = mapped_column(String(16), default="user", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    failed_logins: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    locked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    password_changed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    sessions: Mapped[list[RefreshToken]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )

    __table_args__ = (
        UniqueConstraint("email", name="uq_users_email"),
        Index("ix_users_role", "role"),
    )


class RefreshToken(Base):
    """Un refresh token = une session. Rotation : l'ancien est révoqué et pointe vers le nouveau."""

    __tablename__ = "refresh_tokens"

    id: Mapped[str] = mapped_column(ID, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    family_id: Mapped[str] = mapped_column(ID, nullable=False)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    device_label: Mapped[str | None] = mapped_column(String(80))
    platform: Mapped[str | None] = mapped_column(String(16))
    app_version: Mapped[str | None] = mapped_column(String(24))
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    revoked_reason: Mapped[str | None] = mapped_column(String(32))
    replaced_by_id: Mapped[str | None] = mapped_column(ID)

    user: Mapped[User] = relationship(back_populates="sessions")

    __table_args__ = (
        Index("ix_refresh_tokens_user_family", "user_id", "family_id"),
        Index("ix_refresh_tokens_expires", "expires_at"),
    )


# --- Catalogue -------------------------------------------------------------


class Competition(Base, TimestampMixin):
    """Catalogue des compétitions.

    `coverage_state` est calculé par le plan de couverture (docs/09 §3.2) :
    - `served`        : cotes automatiques + Value (dans le budget de crédits) ;
    - `opportunistic` : cotes à la demande, cache long ;
    - `catalog`       : fiche visible, aucune cote automatique ;
    - `disabled`      : masquée (licence, saison terminée).
    """

    __tablename__ = "competitions"

    code: Mapped[str] = mapped_column(CODE, primary_key=True)
    name: Mapped[str] = mapped_column(SHORT, nullable=False)
    country_code: Mapped[str | None] = mapped_column(String(2))
    confederation: Mapped[str | None] = mapped_column(String(8))
    is_international: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    tier: Mapped[int] = mapped_column(Integer, default=3, nullable=False)
    season: Mapped[str | None] = mapped_column(String(16))
    coverage_state: Mapped[str] = mapped_column(
        String(16), default="catalog", nullable=False, index=True
    )
    demand_score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    notes: Mapped[str | None] = mapped_column(Text)

    __table_args__ = (Index("ix_competitions_coverage_demand", "coverage_state", "demand_score"),)


# --- Exploitation ----------------------------------------------------------


class ApiQuotaLedger(Base):
    """Un crédit fournisseur consommé = une ligne. Sert d'arrêt dur (docs/09 §3.3)."""

    __tablename__ = "api_quota_ledger"

    provider: Mapped[str] = mapped_column(String(24), primary_key=True)
    day: Mapped[date] = mapped_column(Date, primary_key=True)
    credits_used: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    credits_reserved: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    note: Mapped[str | None] = mapped_column(String(120))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP"), nullable=False
    )


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[str] = mapped_column(ID, primary_key=True)
    actor_id: Mapped[str | None] = mapped_column(String(40))
    action: Mapped[str] = mapped_column(String(64), nullable=False)
    target_type: Mapped[str | None] = mapped_column(String(32))
    target_id: Mapped[str | None] = mapped_column(String(64))
    before: Mapped[str | None] = mapped_column(Text)
    after: Mapped[str | None] = mapped_column(Text)
    request_id: Mapped[str | None] = mapped_column(String(40))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP"), nullable=False
    )

    __table_args__ = (Index("ix_audit_logs_actor_created", "actor_id", "created_at"),)


# --- Référentiel sportif minimal (Phase 3) ---------------------------------


class DataSource(Base):
    __tablename__ = "data_sources"

    code: Mapped[str] = mapped_column(CODE, primary_key=True)
    name: Mapped[str] = mapped_column(SHORT, nullable=False)
    license_ref: Mapped[str | None] = mapped_column(String(120))
    reliability_weight: Mapped[float] = mapped_column(Numeric(3, 2), default=1.0, nullable=False)


class Team(Base, TimestampMixin):
    __tablename__ = "teams"

    id: Mapped[str] = mapped_column(ID, primary_key=True)
    name: Mapped[str] = mapped_column(SHORT, nullable=False)
    short_name: Mapped[str | None] = mapped_column(String(40))
    country_code: Mapped[str | None] = mapped_column(String(2))
    external_refs: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    logo_url: Mapped[str | None] = mapped_column(String(255))
    elo_rating: Mapped[float] = mapped_column(Numeric(7, 2), default=1500.0, nullable=False)


class Match(Base, TimestampMixin):
    __tablename__ = "matches"

    id: Mapped[str] = mapped_column(ID, primary_key=True)
    competition_code: Mapped[str] = mapped_column(
        ForeignKey("competitions.code", ondelete="CASCADE"), nullable=False, index=True
    )
    season: Mapped[str | None] = mapped_column(String(16))
    round: Mapped[str | None] = mapped_column(String(40))
    kickoff_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True
    )
    kickoff_local: Mapped[datetime | None] = mapped_column(DateTime())
    venue_timezone: Mapped[str] = mapped_column(String(64), default="UTC", nullable=False)
    home_team_id: Mapped[str] = mapped_column(ForeignKey("teams.id"), nullable=False)
    away_team_id: Mapped[str] = mapped_column(ForeignKey("teams.id"), nullable=False)
    status: Mapped[str] = mapped_column(String(16), default="scheduled", nullable=False)
    minute: Mapped[int | None] = mapped_column(Integer)
    home_score: Mapped[int | None] = mapped_column(Integer)
    away_score: Mapped[int | None] = mapped_column(Integer)
    home_score_ht: Mapped[int | None] = mapped_column(Integer)
    away_score_ht: Mapped[int | None] = mapped_column(Integer)
    data_quality_score: Mapped[float] = mapped_column(Numeric(4, 3), default=0.5, nullable=False)
    source_id: Mapped[str] = mapped_column(ForeignKey("data_sources.code"), nullable=False)
    source_event_id: Mapped[str] = mapped_column(String(80), nullable=False)
    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        UniqueConstraint("source_id", "source_event_id", name="uq_matches_source_event"),
        Index("ix_matches_competition_kickoff", "competition_code", "kickoff_utc"),
        Index("ix_matches_status_kickoff", "status", "kickoff_utc"),
    )


class Bookmaker(Base, TimestampMixin):
    __tablename__ = "bookmakers"

    code: Mapped[str] = mapped_column(CODE, primary_key=True)
    name: Mapped[str] = mapped_column(SHORT, nullable=False)
    access_channel: Mapped[str] = mapped_column(String(16), default="api", nullable=False)
    countries: Mapped[list] = mapped_column(JSON, default=list, nullable=False)


class Market(Base):
    __tablename__ = "markets"

    code: Mapped[str] = mapped_column(CODE, primary_key=True)
    name: Mapped[str] = mapped_column(SHORT, nullable=False)
    family: Mapped[str] = mapped_column(String(24), nullable=False)
    settlement_rules: Mapped[str | None] = mapped_column(Text)


class OddsSnapshot(Base):
    __tablename__ = "odds_snapshots"

    id: Mapped[str] = mapped_column(ID, primary_key=True)
    match_id: Mapped[str] = mapped_column(
        ForeignKey("matches.id", ondelete="CASCADE"), nullable=False, index=True
    )
    bookmaker_code: Mapped[str] = mapped_column(ForeignKey("bookmakers.code"), nullable=False)
    market_code: Mapped[str] = mapped_column(ForeignKey("markets.code"), nullable=False)
    selection_code: Mapped[str] = mapped_column(String(24), nullable=False)
    line: Mapped[float | None] = mapped_column(Numeric(6, 2))
    decimal_odds: Mapped[float] = mapped_column(Numeric(9, 4), nullable=False)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    observed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True
    )
    source_id: Mapped[str] = mapped_column(ForeignKey("data_sources.code"), nullable=False)
    source_payload_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    raw_payload: Mapped[str | None] = mapped_column(Text)

    __table_args__ = (
        Index(
            "ix_odds_match_market_selection_observed",
            "match_id",
            "market_code",
            "selection_code",
            "observed_at",
        ),
    )


class IngestionRun(Base):
    __tablename__ = "ingestion_runs"

    id: Mapped[str] = mapped_column(ID, primary_key=True)
    source_id: Mapped[str] = mapped_column(ForeignKey("data_sources.code"), nullable=False)
    job_name: Mapped[str] = mapped_column(String(64), nullable=False)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    status: Mapped[str] = mapped_column(String(16), default="running", nullable=False)
    matches_upserted: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    odds_appended: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    credits_spent: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    error: Mapped[str | None] = mapped_column(Text)


# --- Modèles et prédictions (Phase 4) --------------------------------------


class ModelVersion(Base, TimestampMixin):
    __tablename__ = "model_versions"

    id: Mapped[str] = mapped_column(ID, primary_key=True)
    code: Mapped[str] = mapped_column(String(40), unique=True, nullable=False)
    status: Mapped[str] = mapped_column(String(16), default="candidate", nullable=False)
    metrics: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    artifact_uri: Mapped[str | None] = mapped_column(String(255))
    checksum: Mapped[str | None] = mapped_column(String(64))
    parent_id: Mapped[str | None] = mapped_column(String(40))


class Prediction(Base):
    __tablename__ = "predictions"

    id: Mapped[str] = mapped_column(ID, primary_key=True)
    match_id: Mapped[str] = mapped_column(
        ForeignKey("matches.id", ondelete="CASCADE"), nullable=False, index=True
    )
    model_version_id: Mapped[str] = mapped_column(
        ForeignKey("model_versions.id"), nullable=False, index=True
    )
    market_code: Mapped[str] = mapped_column(ForeignKey("markets.code"), nullable=False)
    line: Mapped[float | None] = mapped_column(Numeric(6, 2))
    selection_code: Mapped[str] = mapped_column(String(24), nullable=False)
    probability: Mapped[float] = mapped_column(Numeric(6, 5), nullable=False)
    ci_low: Mapped[float] = mapped_column(Numeric(6, 5), nullable=False)
    ci_high: Mapped[float] = mapped_column(Numeric(6, 5), nullable=False)
    data_quality_score: Mapped[float] = mapped_column(Numeric(4, 3), default=0.5, nullable=False)
    features_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    prev_hash: Mapped[str | None] = mapped_column(String(64))
    row_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    __table_args__ = (
        Index("ix_predictions_match_created", "match_id", "created_at"),
        Index("ix_predictions_model", "model_version_id"),
    )


class PredictionContext(Base):
    __tablename__ = "prediction_contexts"

    id: Mapped[str] = mapped_column(ID, primary_key=True)
    prediction_id: Mapped[str] = mapped_column(
        ForeignKey("predictions.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    features: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


# --- Value Betting (Phase 5) ------------------------------------------------


class ValueBet(Base):
    __tablename__ = "value_bets"

    id: Mapped[str] = mapped_column(ID, primary_key=True)
    match_id: Mapped[str] = mapped_column(
        ForeignKey("matches.id", ondelete="CASCADE"), nullable=False, index=True
    )
    odds_snapshot_id: Mapped[str] = mapped_column(ForeignKey("odds_snapshots.id"), nullable=False)
    prediction_id: Mapped[str] = mapped_column(ForeignKey("predictions.id"), nullable=False)
    market_code: Mapped[str] = mapped_column(ForeignKey("markets.code"), nullable=False)
    selection_code: Mapped[str] = mapped_column(String(24), nullable=False)
    line: Mapped[float | None] = mapped_column(Numeric(6, 2))
    implied_prob_novig: Mapped[float] = mapped_column(Numeric(6, 5), nullable=False)
    fair_odds: Mapped[float] = mapped_column(Numeric(9, 4), nullable=False)
    ev: Mapped[float] = mapped_column(Numeric(8, 5), nullable=False)
    ev_lower: Mapped[float] = mapped_column(Numeric(8, 5), nullable=False)
    edge: Mapped[float] = mapped_column(Numeric(8, 5), nullable=False)
    score: Mapped[float] = mapped_column(Numeric(6, 4), nullable=False)
    priority: Mapped[str] = mapped_column(String(8), nullable=False)
    gate_results: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    explanation: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    status: Mapped[str] = mapped_column(String(16), default="active", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


# --- Simulation (Phase 7) ---------------------------------------------------


class Bankroll(Base, TimestampMixin):
    __tablename__ = "bankrolls"

    id: Mapped[str] = mapped_column(ID, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(60), nullable=False)
    currency: Mapped[str] = mapped_column(String(8), default="EUR", nullable=False)
    initial_capital: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    current_capital: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    kelly_fraction: Mapped[float] = mapped_column(Numeric(4, 3), default=0.25, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class SimulatedBet(Base):
    __tablename__ = "simulated_bets"

    id: Mapped[str] = mapped_column(ID, primary_key=True)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    bankroll_id: Mapped[str] = mapped_column(
        ForeignKey("bankrolls.id", ondelete="CASCADE"), nullable=False, index=True
    )
    value_bet_id: Mapped[str] = mapped_column(ForeignKey("value_bets.id"), nullable=False)
    stake: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    odds_taken: Mapped[float] = mapped_column(Numeric(9, 4), nullable=False)
    status: Mapped[str] = mapped_column(String(16), default="pending", nullable=False)
    payout: Mapped[float | None] = mapped_column(Numeric(12, 2))
    profit_loss: Mapped[float | None] = mapped_column(Numeric(12, 2))
    placed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    settled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
