"""Initial schema

Revision ID: 001_initial
Revises:
Create Date: 2026-05-31

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "tenants",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("tenant_id", sa.String(100), nullable=False, unique=True),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("school_type", sa.String(50), nullable=True),
        sa.Column("bundesland", sa.String(5), nullable=True),
        sa.Column("city", sa.String(100), nullable=True),
        sa.Column("contact_email", sa.String(255), nullable=True),
        sa.Column("lat", sa.Float(), nullable=True),
        sa.Column("lon", sa.Float(), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="active"),
        sa.Column("created_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_tenants_tenant_id", "tenants", ["tenant_id"], unique=True)

    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("email", sa.String(255), nullable=False, unique=True),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("display_name", sa.String(100), nullable=False),
        sa.Column("role", sa.String(20), nullable=False, server_default="user"),
        sa.Column("email_verified", sa.Boolean(), server_default="0"),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenants.id"), nullable=True),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "mqtt_accounts",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("username", sa.String(100), nullable=False, unique=True),
        sa.Column("role", sa.String(20), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_mqtt_accounts_username", "mqtt_accounts", ["username"], unique=True)

    op.create_table(
        "devices",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("device_id", sa.String(100), nullable=False),
        sa.Column("device_type", sa.String(20), nullable=False),
        sa.Column("description", sa.String(200), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column(
            "mqtt_account_id",
            sa.Integer(),
            sa.ForeignKey("mqtt_accounts.id"),
            nullable=True,
        ),
    )


def downgrade():
    op.drop_table("devices")
    op.drop_table("mqtt_accounts")
    op.drop_table("users")
    op.drop_table("tenants")
