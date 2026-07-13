"""Leftmost-greedy matcher with canonical-parse backtracking.

A query is a product of universes. At each product position candidate faces are
tried longest-first, ties broken by declaration order (entry index, then face
index); the first candidate that lets the rest of the product match wins. This
is the canonical parse for non-uniquely-decodable face sets (decision 4).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING

from Himark.core.universe import Entry, Query, Universe

if TYPE_CHECKING:
    from collections.abc import Iterator

# One product position's candidate: (face spelling, its entry, face index).
_Candidate = tuple[str, Entry, int]


@dataclass(frozen=True)
class MatchPart:
    """What matched at one product position: its span, entry, and face index."""

    span: tuple[int, int]
    entry: Entry
    face_index: int

    @property
    def face(self) -> str:
        """The face spelling that matched at this position."""
        return self.entry.faces[self.face_index]


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
    value: int
    face_value: int

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


def _candidates(universe: Universe) -> list[_Candidate]:
    """List a universe's faces sorted longest-first, then by declaration order."""
    cands = [
        (face, entry, face_index)
        for entry in universe.entries
        for face_index, face in enumerate(entry.faces)
    ]
    cands.sort(key=lambda c: (-len(c[0]), c[1].value, c[2]))
    return cands


def _try_product(
    candidates: list[list[_Candidate]],
    text: str,
    pos: int,
    depth: int,
) -> list[MatchPart] | None:
    """Match the product from ``depth`` onward at ``pos``; ``None`` if it can't."""
    if depth == len(candidates):
        return []
    for face, entry, face_index in candidates[depth]:
        if text.startswith(face, pos):
            end = pos + len(face)
            tail = _try_product(candidates, text, end, depth + 1)
            if tail is not None:
                return [MatchPart((pos, end), entry, face_index), *tail]
    return None


def _build_match(universes: tuple[Universe, ...], parts: list[MatchPart], start: int) -> Match:
    """Assemble a :class:`Match`, folding both axes as mixed radix (decision 9)."""
    value = 0
    face_value = 0
    for universe, part in zip(universes, parts, strict=True):
        value = value * len(universe.entries) + part.entry.value
        face_value = face_value * len(part.entry.faces) + part.face_index
    end = parts[-1].span[1] if parts else start
    return Match((start, end), tuple(parts), value, face_value)


def match(query: Query, text: str, start: int = 0) -> Match | None:
    """Return the leftmost match at or after ``start``, or ``None`` if there is none."""
    candidates = [_candidates(universe) for universe in query.universes]
    for pos in range(start, len(text) + 1):
        parts = _try_product(candidates, text, pos, 0)
        if parts is not None:
            return _build_match(query.universes, parts, pos)
    return None


def finditer(query: Query, text: str) -> Iterator[Match]:
    """Yield non-overlapping matches left to right, resuming past each span."""
    pos = 0
    while (found := match(query, text, pos)) is not None:
        yield found
        pos = max(found.span[1], pos + 1)
