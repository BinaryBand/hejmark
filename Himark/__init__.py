"""Himark: a query language over pointed alphabets.

Public API: :func:`parse` denotes source to a :class:`Query`; :func:`match` and
:func:`finditer` scan text (accepting a :class:`Query` or raw source).
"""

from __future__ import annotations

from Himark.adapters.parser import to_ast
from Himark.core.engine import finditer as _finditer
from Himark.core.engine import match as _match
from Himark.core.engine import parse as _parse
from Himark.core.match import Match, MatchPart
from Himark.core.syntax import HimarkSyntaxError
from Himark.core.universe import Entry, Query, Universe


def parse(source: str) -> Query:
    """Parse and denote *source* into a :class:`Query`."""
    return _parse(to_ast, source)


def match(query: Query | str, text: str, start: int = 0) -> Match | None:
    """Return the leftmost match of *query* in *text* at or after *start*."""
    return _match(to_ast, query, text, start)


def finditer(query: Query | str, text: str):  # noqa: ANN201
    """Yield non-overlapping matches of *query* across *text*, left to right."""
    return _finditer(to_ast, query, text)


__all__ = [
    "Entry",
    "HimarkSyntaxError",
    "Match",
    "MatchPart",
    "Query",
    "Universe",
    "finditer",
    "match",
    "parse",
]
