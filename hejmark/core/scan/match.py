"""Leftmost-greedy matcher: set membership over spellings, nothing else.

A query is a product of universes. At each product position the matcher probes
prefixes of the remaining text longest-first (maximal munch): a candidate face
is a prefix of ``text[pos:]``, so there are at most ``len(text) - pos`` of
them, and a single ``contains`` accepts or rejects each. The first length that
lets the rest of the product match wins -- the canonical parse. The matcher
knows only spellings: no value or ordinal semantics leak in, and the empty
spelling is never accepted (no zero-width match).
"""

from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass

from hejmark.core.floor.universe import Query, Universe


@dataclass(frozen=True)
class MatchPart:
    """What matched at one product position: its span and the face that hit."""

    span: tuple[int, int]
    face: str


@dataclass(frozen=True)
class Match:
    """A whole match: its overall span and one part per product position."""

    span: tuple[int, int]
    parts: tuple[MatchPart, ...]


def _try_product(
    universes: tuple[Universe, ...],
    text: str,
    pos: int,
    depth: int,
) -> list[MatchPart] | None:
    """Match the product from ``depth`` onward at ``pos``; ``None`` if it can't."""
    if depth == len(universes):
        return []
    universe = universes[depth]
    for length in range(len(text) - pos, 0, -1):
        face = text[pos : pos + length]
        if not universe.contains(face):
            continue
        end = pos + length
        tail = _try_product(universes, text, end, depth + 1)
        if tail is not None:
            return [MatchPart((pos, end), face), *tail]
    return None


def match(query: Query, text: str, start: int = 0) -> Match | None:
    """Return the leftmost match at or after ``start``, or ``None`` if there is none."""
    for pos in range(start, len(text) + 1):
        parts = _try_product(query.universes, text, pos, 0)
        if parts is not None:
            end = parts[-1].span[1] if parts else pos
            return Match((pos, end), tuple(parts))
    return None


def finditer(query: Query, text: str) -> Iterator[Match]:
    """Yield non-overlapping matches left to right, resuming past each span."""
    pos = 0
    while (found := match(query, text, pos)) is not None:
        yield found
        pos = max(found.span[1], pos + 1)
