"""Réponses possibles montrées en fin de manche quand un joueur s'est trompé
ou n'a rien trouvé : de quoi apprendre pour la prochaine fois."""

import random

from sqlalchemy.ext.asyncio import AsyncSession

from app.services.hint_service import popular_answers

# On pioche parmi les réponses les plus connues : « Madrid » plutôt qu'un village.
_POOL = 10


async def example_answers(
    session: AsyncSession,
    language: str,
    categories: list[str],
    letter: str,
    rng: random.Random | None = None,
) -> dict[str, str]:
    """Une réponse valide et connue par catégorie (absente si aucune n'existe)."""
    rng = rng or random.Random()
    examples: dict[str, str] = {}
    for category in categories:
        answers = (await popular_answers(session, category, language, letter))[:_POOL]
        if answers:
            examples[category] = rng.choice(answers)
    return examples
