"""phase 7 — simulation et statistiques"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "0005_simulation"
down_revision = "0004_value"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "bankrolls",
        sa.Column("id", sa.String(length=40), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(length=40),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("name", sa.String(length=60), nullable=False),
        sa.Column("currency", sa.String(length=8), nullable=False, server_default="EUR"),
        sa.Column("initial_capital", sa.Numeric(12, 2), nullable=False),
        sa.Column("current_capital", sa.Numeric(12, 2), nullable=False),
        sa.Column("kelly_fraction", sa.Numeric(4, 3), nullable=False, server_default="0.25"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )

    op.create_table(
        "simulated_bets",
        sa.Column("id", sa.String(length=40), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(length=40),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "bankroll_id",
            sa.String(length=40),
            sa.ForeignKey("bankrolls.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "value_bet_id", sa.String(length=40), sa.ForeignKey("value_bets.id"), nullable=False
        ),
        sa.Column("stake", sa.Numeric(12, 2), nullable=False),
        sa.Column("odds_taken", sa.Numeric(9, 4), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="pending"),
        sa.Column("payout", sa.Numeric(12, 2)),
        sa.Column("profit_loss", sa.Numeric(12, 2)),
        sa.Column(
            "placed_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column("settled_at", sa.DateTime(timezone=True)),
    )


def downgrade() -> None:
    op.drop_table("simulated_bets")
    op.drop_table("bankrolls")
