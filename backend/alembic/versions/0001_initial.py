"""initial schema (phase 2)

Revision ID: 0001_initial
Revises:
Create Date: 2026-10-30

Crée : users, refresh_tokens, competitions, api_quota_ledger, audit_logs.
Les tables de cotes, prédictions et value bets arrivent en Phase 3–4 (voir db/schema.sql).
"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.String(length=40), primary_key=True),
        sa.Column("email", sa.String(length=320), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("display_name", sa.String(length=60)),
        sa.Column("locale", sa.String(length=8), nullable=False, server_default="fr"),
        sa.Column(
            "timezone", sa.String(length=64), nullable=False, server_default="Africa/Ouagadougou"
        ),
        sa.Column("role", sa.String(length=16), nullable=False, server_default="user"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("failed_logins", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("locked_until", sa.DateTime(timezone=True)),
        sa.Column("last_login_at", sa.DateTime(timezone=True)),
        sa.Column("password_changed_at", sa.DateTime(timezone=True)),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.UniqueConstraint("email", name="uq_users_email"),
    )
    op.create_index("ix_users_email", "users", ["email"])
    op.create_index("ix_users_role", "users", ["role"])

    op.create_table(
        "refresh_tokens",
        sa.Column("id", sa.String(length=40), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(length=40),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("family_id", sa.String(length=40), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False, unique=True),
        sa.Column("device_label", sa.String(length=80)),
        sa.Column("platform", sa.String(length=16)),
        sa.Column("app_version", sa.String(length=24)),
        sa.Column("issued_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True)),
        sa.Column("revoked_at", sa.DateTime(timezone=True)),
        sa.Column("revoked_reason", sa.String(length=32)),
        sa.Column("replaced_by_id", sa.String(length=40)),
    )
    op.create_index("ix_refresh_tokens_user_family", "refresh_tokens", ["user_id", "family_id"])
    op.create_index("ix_refresh_tokens_expires", "refresh_tokens", ["expires_at"])

    op.create_table(
        "competitions",
        sa.Column("code", sa.String(length=12), primary_key=True),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("country_code", sa.String(length=2)),
        sa.Column("confederation", sa.String(length=8)),
        sa.Column("is_international", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("tier", sa.Integer(), nullable=False, server_default="3"),
        sa.Column("season", sa.String(length=16)),
        sa.Column("coverage_state", sa.String(length=16), nullable=False, server_default="catalog"),
        sa.Column("demand_score", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("notes", sa.Text()),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )
    op.create_index(
        "ix_competitions_coverage_demand",
        "competitions",
        ["coverage_state", "demand_score"],
    )

    op.create_table(
        "api_quota_ledger",
        sa.Column("provider", sa.String(length=24), primary_key=True),
        sa.Column("day", sa.Date(), primary_key=True),
        sa.Column("credits_used", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("credits_reserved", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("note", sa.String(length=120)),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )

    op.create_table(
        "audit_logs",
        sa.Column("id", sa.String(length=40), primary_key=True),
        sa.Column("actor_id", sa.String(length=40)),
        sa.Column("action", sa.String(length=64), nullable=False),
        sa.Column("target_type", sa.String(length=32)),
        sa.Column("target_id", sa.String(length=64)),
        sa.Column("before", sa.Text()),
        sa.Column("after", sa.Text()),
        sa.Column("request_id", sa.String(length=40)),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )
    op.create_index("ix_audit_logs_actor_created", "audit_logs", ["actor_id", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_audit_logs_actor_created", table_name="audit_logs")
    op.drop_table("audit_logs")
    op.drop_table("api_quota_ledger")
    op.drop_index("ix_competitions_coverage_demand", table_name="competitions")
    op.drop_table("competitions")
    op.drop_index("ix_refresh_tokens_expires", table_name="refresh_tokens")
    op.drop_index("ix_refresh_tokens_user_family", table_name="refresh_tokens")
    op.drop_table("refresh_tokens")
    op.drop_index("ix_users_role", table_name="users")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")
