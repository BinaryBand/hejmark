"""Engine orchestration: wire a parser port to core denotation and matching.

This module combines a parser adapter (injected via the :class:`ToAst` port)
with core's ``denote`` and ``match``/``finditer``.  The adapter is never
imported here -- it is passed in by the composition root (cli / library entry
point), keeping the dependency arrow strictly inward.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from Himark.core.match import Match
from Himark.core.match import finditer as _finditer
from Himark.core.match import match as _match
from Himark.core.universe import Query, denote

if TYPE_CHECKING:
    from collections.abc import Iterator

    from Himark.core.ports import ToAst


def parse(to_ast: ToAst, source: str) -> Query:
    """Parse and denote *source* into a :class:`Query` (universes, most-significant-first)."""
    node = to_ast(source)
    return Query(source, tuple(denote(universe) for universe in node.universes))


def _as_query(to_ast: ToAst, query: Query | str) -> Query:
    """Coerce raw source to a denoted query; pass an existing query through."""
    return parse(to_ast, query) if isinstance(query, str) else query


def match(to_ast: ToAst, query: Query | str, text: str, start: int = 0) -> Match | None:
    """Return the leftmost match of *query* in *text* at or after *start*."""
    return _match(_as_query(to_ast, query), text, start)


def finditer(to_ast: ToAst, query: Query | str, text: str) -> Iterator[Match]:
    """Yield non-overlapping matches of *query* across *text*, left to right."""
    return _finditer(_as_query(to_ast, query), text)
