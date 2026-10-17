"""bonus hints purchased with coins

Revision ID: c3f8d1a60e27
Revises: b7e2a91c4d18
Create Date: 2026-10-17 17:15:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c3f8d1a60e27"
down_revision: Union[str, None] = "b7e2a91c4d18"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "games",
        sa.Column("bonus_hints", sa.Integer(), nullable=False, server_default="0"),
    )


def downgrade() -> None:
    op.drop_column("games", "bonus_hints")
