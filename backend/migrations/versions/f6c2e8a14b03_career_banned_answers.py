"""career world bans previously used answers

Revision ID: f6c2e8a14b03
Revises: e5b1d3f92a47
Create Date: 2026-10-17 19:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f6c2e8a14b03"
down_revision: Union[str, None] = "e5b1d3f92a47"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "games",
        sa.Column("banned_answers", sa.JSON(), nullable=False, server_default="{}"),
    )


def downgrade() -> None:
    op.drop_column("games", "banned_answers")
