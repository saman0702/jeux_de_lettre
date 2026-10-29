"""profile secret hash

Revision ID: c4e7a9d21f60
Revises: bdf8ddee6bd4
Create Date: 2026-10-26 11:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c4e7a9d21f60'
down_revision: Union[str, None] = 'bdf8ddee6bd4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Empreinte du jeton secret de l'appli : seul le téléphone qui l'a créé agit sur le profil.
    op.add_column('profiles', sa.Column('secret_hash', sa.String(length=64), nullable=True))


def downgrade() -> None:
    op.drop_column('profiles', 'secret_hash')
