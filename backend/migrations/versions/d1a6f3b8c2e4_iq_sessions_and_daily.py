"""iq sessions and daily challenge

Revision ID: d1a6f3b8c2e4
Revises: c4e7a9d21f60
Create Date: 2026-10-26 12:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd1a6f3b8c2e4'
down_revision: Union[str, None] = 'c4e7a9d21f60'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'iq_sessions',
        sa.Column('id', sa.String(length=32), nullable=False),
        sa.Column('client_id', sa.String(length=64), nullable=False),
        sa.Column('nickname', sa.String(length=32), nullable=False),
        sa.Column('mode', sa.String(length=8), nullable=False),
        sa.Column('day', sa.Date(), nullable=True),
        sa.Column('duration', sa.Integer(), nullable=False),
        sa.Column('speed_bonus', sa.Boolean(), nullable=False),
        sa.Column('penalty', sa.Boolean(), nullable=False),
        sa.Column('puzzles', sa.JSON(), nullable=False),
        sa.Column('number', sa.Integer(), nullable=False),
        sa.Column('served_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('answered', sa.Boolean(), nullable=False),
        sa.Column('extra_seconds', sa.Integer(), nullable=False),
        sa.Column('jokers', sa.JSON(), nullable=False),
        sa.Column('score', sa.Integer(), nullable=False),
        sa.Column('correct', sa.Integer(), nullable=False),
        sa.Column('results', sa.JSON(), nullable=False),
        sa.Column('elapsed_ms', sa.Integer(), nullable=False),
        sa.Column('finished', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('client_id', 'day', name='uq_iq_daily_attempt'),
    )
    op.create_index('ix_iq_sessions_client_id', 'iq_sessions', ['client_id'])
    op.create_index('ix_iq_sessions_day', 'iq_sessions', ['day'])
    op.create_table(
        'iq_daily_payouts',
        sa.Column('day', sa.Date(), nullable=False),
        sa.Column('paid_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('day'),
    )


def downgrade() -> None:
    op.drop_table('iq_daily_payouts')
    op.drop_index('ix_iq_sessions_day', table_name='iq_sessions')
    op.drop_index('ix_iq_sessions_client_id', table_name='iq_sessions')
    op.drop_table('iq_sessions')
