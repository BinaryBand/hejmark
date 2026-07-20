"""hejmark: a query language over pointed alphabets.

Public API: :func:`parse` denotes source to a :class:`Query`; :func:`match` and
:func:`finditer` scan text (accepting a :class:`Query` or raw source);
:func:`run` executes a whole ``.hmk`` script -- declarations and emit
statements -- against a document.
"""

from __future__ import annotations

from collections.abc import Iterator

from hejmark.adapters.parser import AntlrParser
from hejmark.core import emit
from hejmark.core.engine import finditer as _finditer
from hejmark.core.engine import match as _match
from hejmark.core.engine import parse as _parse
from hejmark.core.engine import script as _script
from hejmark.core.match import Match, MatchPart
from hejmark.core.resolve import statements as _statements
from hejmark.core.surface import HimarkScopeError
from hejmark.core.syntax import HimarkSyntaxError
from hejmark.core.universe import Entry, HimarkUnsettledError, Query, Universe

_to_ast = AntlrParser().to_ast


def parse(source: str) -> Query:
    """Parse and denote *source* into a :class:`Query`."""
    return _parse(_to_ast, source)


def match(query: Query | str, text: str, start: int = 0) -> Match | None:
    """Return the leftmost match of *query* in *text* at or after *start*."""
    return _match(_to_ast, query, text, start)


def finditer(query: Query | str, text: str) -> Iterator[Match]:
    """Yield non-overlapping matches of *query* across *text*, left to right."""
    return _finditer(_to_ast, query, text)


def run(source: str, text: str) -> str:
    """Run a whole script against *text*, returning the spliced document."""
    node, env = _script(_to_ast, source)
    return emit.run(_statements(node), text, env)


__all__ = [
    "Entry",
    "HimarkScopeError",
    "HimarkSyntaxError",
    "HimarkUnsettledError",
    "Match",
    "MatchPart",
    "Query",
    "Universe",
    "finditer",
    "match",
    "parse",
    "run",
]
