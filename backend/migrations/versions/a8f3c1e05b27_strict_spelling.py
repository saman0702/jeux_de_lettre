"""strict spelling option on games

Revision ID: a8f3c1e05b27
Revises: f6c2e8a14b03
Create Date: 2026-10-18 15:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a8f3c1e05b27"
down_revision: Union[str, None] = "f6c2e8a14b03"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "games",
        sa.Column("strict_spelling", sa.Boolean(), nullable=False, server_default="false"),
    )


def downgrade() -> None:
    op.drop_column("games", "strict_spelling")
