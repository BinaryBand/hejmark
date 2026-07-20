"""Leftmost-greedy matcher: set membership over spellings, nothing else.

A query is a product of factors. At each product position the matcher probes
prefixes of the remaining text longest-first (maximal munch): a candidate face
is a prefix of ``text[pos:]``, so there are at most ``len(text) - pos`` of
them, and a single ``contains`` accepts or rejects each. The first length that
lets the rest of the product match wins -- the canonical parse. The matcher
knows only spellings: no value or ordinal semantics leak in, and the empty
spelling is never accepted (no zero-width match).

A factor is a denoted universe -- or, where its unit back-references a factor
to its left, a :class:`~hejmark.core.surface.late.Late` awaiting the faces
bound so far. The matcher binds factors left to right, so at each position the
late factor's reads are bound and it expands into a plain universe: every
attempt is a floor query, which is the back-reference's whole admission story.
The :class:`Query` lives here rather than on the floor for the same reason --
a query may carry a surface object the floor cannot name.
"""

from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass

from hejmark.core.floor.universe import Universe
from hejmark.core.surface.ast import HimarkScopeError
from hejmark.core.surface.late import Late

# One product position of a query: denoted, or awaiting its binding.
Factor = Universe | Late


@dataclass(frozen=True)
class Query:
    """A denoted query: its source plus one factor per written unit, in order."""

    source: str
    universes: tuple[Factor, ...]

    def universe(self, index: int = 0) -> Universe:
        """The denoted universe at *index*, for callers that need one factor.

        Raises:
            HimarkScopeError: the factor back-references, so it denotes only
                under a binding -- resolve it with :func:`universe_at` instead.
        """
        factor = self.universes[index]
        if isinstance(factor, Late):
            msg = f"factor {index + 1} back-references: it denotes only under a binding"
            raise HimarkScopeError(msg)
        return factor


def universe_at(factor: Factor, bound: tuple[str, ...]) -> Universe:
    """Resolve one factor under the faces bound to its left."""
    return factor.at(bound) if isinstance(factor, Late) else factor


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
    factors: tuple[Factor, ...],
    text: str,
    pos: int,
    depth: int,
    bound: tuple[str, ...],
) -> list[MatchPart] | None:
    """Match the product from ``depth`` onward at ``pos``; ``None`` if it can't."""
    if depth == len(factors):
        return []
    universe = universe_at(factors[depth], bound)
    for length in range(len(text) - pos, 0, -1):
        face = text[pos : pos + length]
        if not universe.contains(face):
            continue
        end = pos + length
        tail = _try_product(factors, text, end, depth + 1, (*bound, face))
        if tail is not None:
            return [MatchPart((pos, end), face), *tail]
    return None


def match(query: Query, text: str, start: int = 0) -> Match | None:
    """Return the leftmost match at or after ``start``, or ``None`` if there is none."""
    for pos in range(start, len(text) + 1):
        parts = _try_product(query.universes, text, pos, 0, ())
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
