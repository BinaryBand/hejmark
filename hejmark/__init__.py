"""hejmark: a query language over pointed alphabets.

Public API: :func:`parse` denotes source to a :class:`Query`; :func:`match` and
:func:`finditer` scan text (accepting a :class:`Query` or raw source);
:func:`run` executes a whole ``.hmk`` script -- declarations and emit
statements -- against a document.
"""

from __future__ import annotations

import json
from collections.abc import Iterator

from hejmark.adapters.parser import AntlrParser
from hejmark.core.compiler.compile import lower as _lower
from hejmark.core.driver import finditer as _finditer
from hejmark.core.driver import match as _match
from hejmark.core.driver import parse as _parse
from hejmark.core.driver import run as _run
from hejmark.core.engine.execute import HimarkSentinelError
from hejmark.core.engine.scan.match import Match, MatchPart, Query
from hejmark.core.floor.syntax import HimarkSyntaxError
from hejmark.core.floor.universe import Entry, HimarkUnsettledError, Universe
from hejmark.core.floor.work import HimarkBudgetError
from hejmark.core.ir.codec import encode_query as _encode_query
from hejmark.core.ir.errors import HimarkScopeError

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
    return _run(_to_ast, source, text)


def emit_json(source: str) -> str:
    """Emit the expanded floor AST of *source* as JSON, for the Rust port to denote.

    The query is parsed and rewritten into the floor's six constructors; the
    result is the portable hand-off the Rust ``find`` binary reads back. A
    back-referencing query cannot be lowered ahead of a binding and is refused.
    """
    return json.dumps(_encode_query(_lower(_to_ast, source)))


__all__ = [
    "Entry",
    "HimarkBudgetError",
    "HimarkScopeError",
    "HimarkSentinelError",
    "HimarkSyntaxError",
    "HimarkUnsettledError",
    "Match",
    "MatchPart",
    "Query",
    "Universe",
    "emit_json",
    "finditer",
    "match",
    "parse",
    "run",
]
