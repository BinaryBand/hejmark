"""Himark: a query language over pointed alphabets.

Public API: :func:`parse` denotes source to a :class:`Query`; :func:`match` and
:func:`finditer` scan text (accepting a :class:`Query` or raw source).
"""

from __future__ import annotations

from Himark.app.engine import finditer, match, parse
from Himark.core.match import Match, MatchPart
from Himark.core.syntax import HimarkSyntaxError
from Himark.core.universe import Entry, Query, Universe

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
