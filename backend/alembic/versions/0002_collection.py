"""phase 3 — collecte (équipes, rencontres, cotes, ingestion)"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "0002_collection"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "data_sources",
        sa.Column("code", sa.String(length=12), primary_key=True),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("license_ref", sa.String(length=120)),
        sa.Column("reliability_weight", sa.Numeric(3, 2), nullable=False, server_default="1.0"),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )

    op.create_table(
        "teams",
        sa.Column("id", sa.String(length=40), primary_key=True),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("short_name", sa.String(length=40)),
        sa.Column("country_code", sa.String(length=2)),
        sa.Column("external_refs", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
        sa.Column("logo_url", sa.String(length=255)),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )

    op.create_table(
        "matches",
        sa.Column("id", sa.String(length=40), primary_key=True),
        sa.Column(
            "competition_code",
            sa.String(length=12),
            sa.ForeignKey("competitions.code", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("season", sa.String(length=16)),
        sa.Column("round", sa.String(length=40)),
        sa.Column("kickoff_utc", sa.DateTime(timezone=True), nullable=False),
        sa.Column("kickoff_local", sa.DateTime()),
        sa.Column("venue_timezone", sa.String(length=64), nullable=False, server_default="UTC"),
        sa.Column("home_team_id", sa.String(length=40), sa.ForeignKey("teams.id"), nullable=False),
        sa.Column("away_team_id", sa.String(length=40), sa.ForeignKey("teams.id"), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="scheduled"),
        sa.Column("minute", sa.Integer()),
        sa.Column("home_score", sa.Integer()),
        sa.Column("away_score", sa.Integer()),
        sa.Column("home_score_ht", sa.Integer()),
        sa.Column("away_score_ht", sa.Integer()),
        sa.Column("data_quality_score", sa.Numeric(4, 3), nullable=False, server_default="0.5"),
        sa.Column(
            "source_id", sa.String(length=12), sa.ForeignKey("data_sources.code"), nullable=False
        ),
        sa.Column("source_event_id", sa.String(length=80), nullable=False),
        sa.Column("last_synced_at", sa.DateTime(timezone=True)),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.UniqueConstraint("source_id", "source_event_id", name="uq_matches_source_event"),
        sa.CheckConstraint("home_team_id <> away_team_id", name="ck_matches_distinct_teams"),
    )
    op.create_index(
        "ix_matches_competition_kickoff", "matches", ["competition_code", "kickoff_utc"]
    )
    op.create_index("ix_matches_status_kickoff", "matches", ["status", "kickoff_utc"])

    op.create_table(
        "bookmakers",
        sa.Column("code", sa.String(length=12), primary_key=True),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("access_channel", sa.String(length=16), nullable=False, server_default="api"),
        sa.Column("countries", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )

    op.create_table(
        "markets",
        sa.Column("code", sa.String(length=12), primary_key=True),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("family", sa.String(length=24), nullable=False),
        sa.Column("settlement_rules", sa.Text()),
    )

    op.create_table(
        "odds_snapshots",
        sa.Column("id", sa.String(length=40), primary_key=True),
        sa.Column(
            "match_id",
            sa.String(length=40),
            sa.ForeignKey("matches.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "bookmaker_code", sa.String(length=12), sa.ForeignKey("bookmakers.code"), nullable=False
        ),
        sa.Column(
            "market_code", sa.String(length=12), sa.ForeignKey("markets.code"), nullable=False
        ),
        sa.Column("selection_code", sa.String(length=24), nullable=False),
        sa.Column("line", sa.Numeric(6, 2)),
        sa.Column("decimal_odds", sa.Numeric(9, 4), nullable=False),
        sa.Column("is_verified", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("is_available", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("observed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "source_id", sa.String(length=12), sa.ForeignKey("data_sources.code"), nullable=False
        ),
        sa.Column("source_payload_hash", sa.String(length=64), nullable=False),
        sa.Column("raw_payload", sa.Text()),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.CheckConstraint("decimal_odds > 1", name="ck_odds_decimal_gt_one"),
    )
    op.create_index(
        "ix_odds_match_market_selection_observed",
        "odds_snapshots",
        ["match_id", "market_code", "selection_code", "observed_at"],
    )

    op.create_table(
        "ingestion_runs",
        sa.Column("id", sa.String(length=40), primary_key=True),
        sa.Column(
            "source_id", sa.String(length=12), sa.ForeignKey("data_sources.code"), nullable=False
        ),
        sa.Column("job_name", sa.String(length=64), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("finished_at", sa.DateTime(timezone=True)),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="running"),
        sa.Column("matches_upserted", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("odds_appended", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("credits_spent", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("error", sa.Text()),
    )


def downgrade() -> None:
    op.drop_table("ingestion_runs")
    op.drop_index("ix_odds_match_market_selection_observed", table_name="odds_snapshots")
    op.drop_table("odds_snapshots")
    op.drop_table("markets")
    op.drop_table("bookmakers")
    op.drop_index("ix_matches_status_kickoff", table_name="matches")
    op.drop_index("ix_matches_competition_kickoff", table_name="matches")
    op.drop_table("matches")
    op.drop_table("teams")
    op.drop_table("data_sources")
