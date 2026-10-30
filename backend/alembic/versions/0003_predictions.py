"""phase 4 — moteur statistique (modèles, prédictions, Elo)"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "0003_predictions"
down_revision = "0002_collection"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "teams", sa.Column("elo_rating", sa.Numeric(7, 2), nullable=False, server_default="1500.00")
    )

    op.create_table(
        "model_versions",
        sa.Column("id", sa.String(length=40), primary_key=True),
        sa.Column("code", sa.String(length=40), nullable=False, unique=True),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="candidate"),
        sa.Column("metrics", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
        sa.Column("artifact_uri", sa.String(length=255)),
        sa.Column("checksum", sa.String(length=64)),
        sa.Column("parent_id", sa.String(length=40)),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )

    op.create_table(
        "predictions",
        sa.Column("id", sa.String(length=40), primary_key=True),
        sa.Column(
            "match_id",
            sa.String(length=40),
            sa.ForeignKey("matches.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "model_version_id",
            sa.String(length=40),
            sa.ForeignKey("model_versions.id"),
            nullable=False,
        ),
        sa.Column(
            "market_code", sa.String(length=12), sa.ForeignKey("markets.code"), nullable=False
        ),
        sa.Column("line", sa.Numeric(6, 2)),
        sa.Column("selection_code", sa.String(length=24), nullable=False),
        sa.Column("probability", sa.Numeric(6, 5), nullable=False),
        sa.Column("ci_low", sa.Numeric(6, 5), nullable=False),
        sa.Column("ci_high", sa.Numeric(6, 5), nullable=False),
        sa.Column("data_quality_score", sa.Numeric(4, 3), nullable=False, server_default="0.5"),
        sa.Column("features_hash", sa.String(length=64), nullable=False),
        sa.Column("prev_hash", sa.String(length=64)),
        sa.Column("row_hash", sa.String(length=64), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )
    op.create_index("ix_predictions_match_created", "predictions", ["match_id", "created_at"])
    op.create_index("ix_predictions_model", "predictions", ["model_version_id"])

    op.create_table(
        "prediction_contexts",
        sa.Column("id", sa.String(length=40), primary_key=True),
        sa.Column(
            "prediction_id",
            sa.String(length=40),
            sa.ForeignKey("predictions.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("features", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )


def downgrade() -> None:
    op.drop_table("prediction_contexts")
    op.drop_index("ix_predictions_model", table_name="predictions")
    op.drop_index("ix_predictions_match_created", table_name="predictions")
    op.drop_table("predictions")
    op.drop_table("model_versions")
    op.drop_column("teams", "elo_rating")
