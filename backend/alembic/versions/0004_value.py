"""phase 5 — value betting (opportunités)"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "0004_value"
down_revision = "0003_predictions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "value_bets",
        sa.Column("id", sa.String(length=40), primary_key=True),
        sa.Column(
            "match_id",
            sa.String(length=40),
            sa.ForeignKey("matches.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "odds_snapshot_id",
            sa.String(length=40),
            sa.ForeignKey("odds_snapshots.id"),
            nullable=False,
        ),
        sa.Column(
            "prediction_id", sa.String(length=40), sa.ForeignKey("predictions.id"), nullable=False
        ),
        sa.Column(
            "market_code", sa.String(length=12), sa.ForeignKey("markets.code"), nullable=False
        ),
        sa.Column("selection_code", sa.String(length=24), nullable=False),
        sa.Column("line", sa.Numeric(6, 2)),
        sa.Column("implied_prob_novig", sa.Numeric(6, 5), nullable=False),
        sa.Column("fair_odds", sa.Numeric(9, 4), nullable=False),
        sa.Column("ev", sa.Numeric(8, 5), nullable=False),
        sa.Column("ev_lower", sa.Numeric(8, 5), nullable=False),
        sa.Column("edge", sa.Numeric(8, 5), nullable=False),
        sa.Column("score", sa.Numeric(6, 4), nullable=False),
        sa.Column("priority", sa.String(length=8), nullable=False),
        sa.Column("gate_results", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
        sa.Column("explanation", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="active"),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )
    op.create_index("ix_value_bets_match_priority", "value_bets", ["match_id", "priority", "score"])


def downgrade() -> None:
    op.drop_index("ix_value_bets_match_priority", table_name="value_bets")
    op.drop_table("value_bets")
