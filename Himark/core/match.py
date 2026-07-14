"""Leftmost-greedy matcher with canonical-parse backtracking.

A query is a product of universes. At each product position the matcher probes
prefixes of the remaining text longest-first: every viable face is a prefix of
``text[pos:]``, so there are at most ``len(text) - pos`` candidates. Claims are
unique, so each prefix belongs to at most one entry -- a single ``lookup``
either identifies it or rejects it, and the old candidate-sort collapses to
longest-first probing. The first length that lets the rest of the product match
wins, which is the canonical parse for non-uniquely-decodable face sets.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING

from Himark.core.ordinal import horner

if TYPE_CHECKING:
    from collections.abc import Iterator

    from Himark.core.ordinal import Ordinal
    from Himark.core.universe import Query, Universe


@dataclass(frozen=True)
class MatchPart:
    """What matched at one product position: its span, face, and derived axes.

    ``face`` is a plain attribute now that entries are derived rather than
    stored: ``value`` and ``face_index`` are the position's coordinates on the
    two axes, and ``face_count`` is its entry's face-axis base for folding.
    """

    span: tuple[int, int]
    face: str
    value: int | Ordinal
    face_index: int | Ordinal
    face_count: int | Ordinal


@dataclass(frozen=True)
class Capture:
    """One numbered span a match decomposes into -- derivation metadata.

    Number 0 is the whole match (the product entry); numbers 1..k are the
    product's operand positions, most-significant-first. A capture is derived,
    never stored: the operand universe and position already name the entry, so
    only the span -- where that entry landed in the text -- is recorded here.
    """

    number: int
    span: tuple[int, int]


@dataclass(frozen=True)
class Match:
    """A whole match: overall span, per-position parts, and both axis values."""

    span: tuple[int, int]
    parts: tuple[MatchPart, ...]
    value: int | Ordinal
    face_value: int | Ordinal

    @property
    def captures(self) -> tuple[Capture, ...]:
        """Number every span: index 0 the whole match, then each position in order."""
        positions = (Capture(i + 1, part.span) for i, part in enumerate(self.parts))
        return (Capture(0, self.span), *positions)

    def capture(self, number: int) -> Capture:
        """Return the capture numbered ``number`` (0 is the whole match)."""
        captures = self.captures
        if not 0 <= number < len(captures):
            msg = f"no capture numbered {number}: match has {len(captures)}"
            raise IndexError(msg)
        return captures[number]


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
        hit = universe.lookup(face)
        if hit is None:
            continue
        value, face_index, face_count = hit
        end = pos + length
        tail = _try_product(universes, text, end, depth + 1)
        if tail is not None:
            part = MatchPart((pos, end), face, value, face_index, face_count)
            return [part, *tail]
    return None


def _build_match(universes: tuple[Universe, ...], parts: list[MatchPart], start: int) -> Match:
    """Assemble a :class:`Match`, folding both axes as ordinal mixed radix."""
    value = horner([u.entry_count for u in universes], [p.value for p in parts])
    face_value = horner([p.face_count for p in parts], [p.face_index for p in parts])
    end = parts[-1].span[1] if parts else start
    return Match((start, end), tuple(parts), value, face_value)


def match(query: Query, text: str, start: int = 0) -> Match | None:
    """Return the leftmost match at or after ``start``, or ``None`` if there is none."""
    for pos in range(start, len(text) + 1):
        parts = _try_product(query.universes, text, pos, 0)
        if parts is not None:
            return _build_match(query.universes, parts, pos)
    return None


def finditer(query: Query, text: str) -> Iterator[Match]:
    """Yield non-overlapping matches left to right, resuming past each span."""
    pos = 0
    while (found := match(query, text, pos)) is not None:
        yield found
        pos = max(found.span[1], pos + 1)
