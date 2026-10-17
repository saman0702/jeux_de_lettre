"""player cosmetics

Revision ID: b7e2a91c4d18
Revises: a1c4e8b27d90
Create Date: 2026-10-17 16:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b7e2a91c4d18"
down_revision: Union[str, None] = "a1c4e8b27d90"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("profiles", sa.Column("cosmetics_owned", sa.String(length=256), nullable=False, server_default=""))
    op.add_column("profiles", sa.Column("cosmetic_frame", sa.String(length=32), nullable=False, server_default=""))
    op.add_column("profiles", sa.Column("cosmetic_name", sa.String(length=32), nullable=False, server_default=""))
    op.add_column("profiles", sa.Column("cosmetic_tiles", sa.String(length=32), nullable=False, server_default=""))
    op.add_column("profiles", sa.Column("cosmetic_victory", sa.String(length=32), nullable=False, server_default=""))


def downgrade() -> None:
    op.drop_column("profiles", "cosmetic_victory")
    op.drop_column("profiles", "cosmetic_tiles")
    op.drop_column("profiles", "cosmetic_name")
    op.drop_column("profiles", "cosmetic_frame")
    op.drop_column("profiles", "cosmetics_owned")
