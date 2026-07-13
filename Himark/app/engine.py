"""Engine orchestration: wire the parser adapter to core denotation and matching.

This is the one place the parser (an adapter) and the pure core meet: core may
not import adapters, so ``parse`` -- which combines ``to_ast`` with ``denote`` --
lives here. ``match`` and ``finditer`` accept either a denoted :class:`Query` or
raw source, parsing strings on the fly.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from Himark.adapters.parser import to_ast
from Himark.core.match import Match
from Himark.core.match import finditer as _finditer
from Himark.core.match import match as _match
from Himark.core.universe import Query, denote

if TYPE_CHECKING:
    from collections.abc import Iterator


def parse(source: str) -> Query:
    """Parse and denote source into a :class:`Query` (universes, most-significant-first)."""
    node = to_ast(source)
    return Query(source, tuple(denote(universe) for universe in node.universes))


def _as_query(query: Query | str) -> Query:
    """Coerce raw source to a denoted query; pass an existing query through."""
    return parse(query) if isinstance(query, str) else query


def match(query: Query | str, text: str, start: int = 0) -> Match | None:
    """Return the leftmost match of ``query`` in ``text`` at or after ``start``."""
    return _match(_as_query(query), text, start)


def finditer(query: Query | str, text: str) -> Iterator[Match]:
    """Yield non-overlapping matches of ``query`` across ``text``, left to right."""
    return _finditer(_as_query(query), text)
