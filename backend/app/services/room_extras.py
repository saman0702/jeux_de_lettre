"""Extras salon : titres, revue des mots, relais, défi éclair."""

from __future__ import annotations

import random
from collections import deque
from dataclasses import dataclass, field
from datetime import datetime

from app.core.game_rules import Category, LIGHTNING_POINTS


@dataclass
class ChatMessage:
    client_id: str
    nickname: str
    text: str
    at: datetime


@dataclass
class Reaction:
    client_id: str
    nickname: str
    sticker: str
    at: datetime


@dataclass
class LightningChallenge:
    letter: str
    category: str
    options: list[str]
    answer: str
    ends_at: datetime
    picks: dict[str, str] = field(default_factory=dict)  # client -> choice
    scores: dict[str, int] = field(default_factory=dict)


def assign_relay_categories(
    categories: list[Category], player_ids: list[str], rng: random.Random | None = None
) -> dict[str, list[str]]:
    """Répartit les catégories entre les joueurs (relais)."""
    rng = rng or random.Random()
    if not player_ids or not categories:
        return {}
    cats = [c.value for c in categories]
    rng.shuffle(cats)
    out: dict[str, list[str]] = {pid: [] for pid in player_ids}
    for i, cat in enumerate(cats):
        out[player_ids[i % len(player_ids)]].append(cat)
    # Au moins une catégorie chacun si possible.
    if len(cats) >= len(player_ids):
        return out
    for i, pid in enumerate(player_ids):
        if not out[pid]:
            out[pid] = [cats[i % len(cats)]]
    return out


def compute_titles(results_history: list[dict], ranking: list[tuple[str, int, str]]) -> dict[str, str]:
    """Titres de salon temporaires à partir des manches et du classement.

    ranking: (client_id, score, nickname)
    results_history: liste de room.results (number, letter, players[{answers, elapsed_ms, ...}])
    """
    titles: dict[str, str] = {}
    if ranking:
        titles[ranking[0][0]] = "champion"
    # Plus rapide (meilleur elapsed moyen sur réponses valides).
    speed: dict[str, list[int]] = {}
    rare: dict[str, int] = {}
    dictionary: dict[str, int] = {}
    for round_results in results_history:
        players = round_results.get("players") or []
        # mots uniques dans la manche
        keys_count: dict[tuple[str, str], int] = {}
        for p in players:
            for a in p.get("answers") or []:
                if a.get("status") != "valid":
                    continue
                key = (a.get("category") or "", (a.get("matched_value") or "").casefold())
                keys_count[key] = keys_count.get(key, 0) + 1
        for p in players:
            cid = p.get("client_id")
            if not cid:
                continue
            valid = [a for a in (p.get("answers") or []) if a.get("status") == "valid"]
            dictionary[cid] = dictionary.get(cid, 0) + len(valid)
            elapsed = p.get("elapsed_ms")
            if isinstance(elapsed, int) and valid:
                speed.setdefault(cid, []).append(elapsed)
            for a in valid:
                key = (a.get("category") or "", (a.get("matched_value") or "").casefold())
                if keys_count.get(key) == 1:
                    rare[cid] = rare.get(cid, 0) + 1

    if speed:
        avg = {cid: sum(v) / len(v) for cid, v in speed.items() if v}
        if avg:
            fastest = min(avg, key=avg.get)
            titles.setdefault(fastest, "speedster")
    if rare:
        rarest = max(rare, key=rare.get)
        titles.setdefault(rarest, "rare_finder")
    if dictionary:
        book = max(dictionary, key=dictionary.get)
        titles.setdefault(book, "dictionary")
    return titles


def _review_fact_lines(category: str, word: str, language: str) -> list[str]:
    """Infos pédagogiques pour la revue (pays, villes, animaux, fruits)."""
    from app.services import fact_service

    lines = list(fact_service.lookup_lines(category, word, language) or [])
    # Ville : enrichir avec les infos du pays associé.
    if category == "city":
        for line in list(lines):
            lower = line.lower()
            if lower.startswith("pays :") or lower.startswith("country:"):
                country = line.split(":", 1)[1].strip()
                if not country:
                    continue
                extra = fact_service.lookup_lines("country", country, language) or []
                for fact in extra:
                    if fact not in lines:
                        lines.append(fact)
                break
    return lines[:6]


def build_word_review(
    results_history: list[dict], limit: int = 16, language: str = "fr"
) -> list[dict]:
    """Mots intéressants de la partie : uniques + infos (pays, villes…)."""
    seen: set[tuple[str, str]] = set()
    review: list[dict] = []
    for round_results in results_history:
        letter = round_results.get("letter") or ""
        players = round_results.get("players") or []
        keys_count: dict[tuple[str, str], int] = {}
        owners: dict[tuple[str, str], list[str]] = {}
        for p in players:
            for a in p.get("answers") or []:
                if a.get("status") != "valid":
                    continue
                word = a.get("matched_value") or a.get("value") or ""
                key = (a.get("category") or "", word.casefold())
                keys_count[key] = keys_count.get(key, 0) + 1
                owners.setdefault(key, []).append(p.get("nickname") or "")
                if key not in seen:
                    seen.add(key)
                    cat = a.get("category") or ""
                    review.append(
                        {
                            "category": cat,
                            "word": word,
                            "letter": letter,
                            "unique": False,
                            "by": [],
                            "facts": _review_fact_lines(cat, word, language),
                        }
                    )
        for item in review:
            key = (item["category"], (item["word"] or "").casefold())
            if key in keys_count:
                item["unique"] = keys_count[key] == 1
                item["by"] = owners.get(key, [])
    # Uniques avec infos d'abord, puis uniques, puis le reste.
    review.sort(
        key=lambda x: (
            not x["unique"],
            not bool(x.get("facts")),
            x["word"],
        )
    )
    return review[:limit]


def score_lightning(challenge: LightningChallenge, client_id: str, choice: str) -> int:
    if client_id in challenge.picks:
        return challenge.scores.get(client_id, 0)
    challenge.picks[client_id] = choice
    points = LIGHTNING_POINTS if choice == challenge.answer else 0
    challenge.scores[client_id] = points
    return points


def trim_chat(messages: deque[ChatMessage], limit: int) -> list[dict]:
    return [
        {
            "client_id": m.client_id,
            "nickname": m.nickname,
            "text": m.text,
            "at": m.at.isoformat(),
        }
        for m in list(messages)[-limit:]
    ]


def trim_reactions(reactions: deque[Reaction], limit: int = 20) -> list[dict]:
    return [
        {
            "client_id": r.client_id,
            "nickname": r.nickname,
            "sticker": r.sticker,
            "at": r.at.isoformat(),
        }
        for r in list(reactions)[-limit:]
    ]
