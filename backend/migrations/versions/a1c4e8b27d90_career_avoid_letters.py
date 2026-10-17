"""career replay avoids previous letters

Revision ID: a1c4e8b27d90
Revises: ff1cbdb93a55
Create Date: 2026-10-17 15:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a1c4e8b27d90"
down_revision: Union[str, None] = "ff1cbdb93a55"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "games",
        sa.Column("avoid_letters", sa.String(length=26), nullable=False, server_default=""),
    )


def downgrade() -> None:
    op.drop_column("games", "avoid_letters")
