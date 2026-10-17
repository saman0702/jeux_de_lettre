"""permanent category info unlocks

Revision ID: d4a9c2e81f36
Revises: c3f8d1a60e27
Create Date: 2026-10-17 17:40:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d4a9c2e81f36"
down_revision: Union[str, None] = "c3f8d1a60e27"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "profiles",
        sa.Column("facts_unlocked", sa.String(length=8192), nullable=False, server_default=""),
    )


def downgrade() -> None:
    op.drop_column("profiles", "facts_unlocked")
