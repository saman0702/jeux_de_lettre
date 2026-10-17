"""avatar hair and hat cosmetics

Revision ID: e5b1d3f92a47
Revises: d4a9c2e81f36
Create Date: 2026-10-17 18:20:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e5b1d3f92a47"
down_revision: Union[str, None] = "d4a9c2e81f36"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "profiles",
        sa.Column("cosmetic_hair", sa.String(length=32), nullable=False, server_default=""),
    )
    op.add_column(
        "profiles",
        sa.Column("cosmetic_hat", sa.String(length=32), nullable=False, server_default=""),
    )
    op.alter_column(
        "profiles",
        "cosmetics_owned",
        existing_type=sa.String(length=256),
        type_=sa.String(length=512),
        existing_nullable=False,
        existing_server_default="",
    )


def downgrade() -> None:
    op.alter_column(
        "profiles",
        "cosmetics_owned",
        existing_type=sa.String(length=512),
        type_=sa.String(length=256),
        existing_nullable=False,
        existing_server_default="",
    )
    op.drop_column("profiles", "cosmetic_hat")
    op.drop_column("profiles", "cosmetic_hair")
