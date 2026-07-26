"""hejmark: a query language over pointed alphabets.

Public API: :func:`parse` denotes source to a :class:`Query`; :func:`match` and
:func:`finditer` scan text (accepting a :class:`Query` or raw source);
:func:`run` executes a whole ``.hmk`` script -- declarations and emit
statements -- against a document.
"""

from __future__ import annotations

import json
from collections.abc import Iterator, Sequence

from hejmark.adapters.library import standard_library
from hejmark.adapters.parser import AntlrParser
from hejmark.core.compiler.compile import Fragment
from hejmark.core.compiler.compile import lower as _lower
from hejmark.core.compiler.compile import lower_fragments as _lower_fragments
from hejmark.core.driver import compile_program as _compile_program
from hejmark.core.driver import finditer as _finditer
from hejmark.core.driver import match as _match
from hejmark.core.driver import parse as _parse
from hejmark.core.driver import run as _run
from hejmark.core.engine.scan.match import Match, MatchPart, Query
from hejmark.core.floor.syntax import HimarkSyntaxError
from hejmark.core.floor.universe import Entry, Universe
from hejmark.core.ir.codec import encode_query as _encode_query
from hejmark.core.ir.errors import HimarkScopeError
from hejmark.core.ir.wire import encode_program as _encode_program

_to_ast = AntlrParser().to_ast


def parse(source: str) -> Query:
    """Parse and denote *source* into a :class:`Query`."""
    return _parse(_to_ast, source, standard_library())


def match(query: Query | str, text: str, start: int = 0) -> Match | None:
    """Return the leftmost match of *query* in *text* at or after *start*."""
    return _match(_to_ast, query, text, start, standard_library())


def finditer(query: Query | str, text: str) -> Iterator[Match]:
    """Yield non-overlapping matches of *query* across *text*, left to right."""
    return _finditer(_to_ast, query, text, standard_library())


def run(source: str, text: str) -> str:
    """Run a whole script against *text*, returning the spliced document."""
    return _run(_to_ast, source, text, standard_library())


def emit_json(source: str) -> str:
    """Emit the expanded floor AST of *source* as JSON, for another engine to denote.

    The query is parsed and rewritten into the floor's five constructors; the
    result is the portable hand-off, stopped at the compiler so a host holding
    its own engine can finish it. A back-referencing query cannot be lowered
    ahead of a binding and is refused.
    """
    return json.dumps(_encode_query(_lower(_to_ast, source, standard_library())))


def emit_fragments(sources: Sequence[str]) -> str:
    """Emit the floor AST of each of *sources* as a JSON array, one entry each.

    The fragment form of :func:`emit_json`, for a host that holds one script as
    separate pieces -- an editor's rule list -- and wants each piece's own
    program while the names declared in any of them stay in scope across all.
    A fragment that declares and asks nothing emits ``null``: it contributes
    names, not a query, which is the whole reason this is not a loop over
    :func:`emit_json`. One that will not compile emits ``{"error": ...}`` and
    the rest still emit their programs, so a host editing fragments separately
    keeps the answers for the ones it is not editing. A refusal about the *set*
    -- a name two fragments declare -- raises, as it does in :func:`emit_json`.
    """
    fragments = _lower_fragments(_to_ast, sources, standard_library())
    return json.dumps([_fragment_payload(one) for one in fragments])


def _fragment_payload(fragment: Fragment) -> dict[str, object] | None:
    """One fragment's wire entry: its query, its error, or null for a declaration."""
    if fragment.error is not None:
        return {"error": fragment.error}
    return None if fragment.forms is None else _encode_query(fragment.forms)


def emit_program(source: str) -> str:
    """Emit a whole compiled script as the versioned Program JSON.

    The script-level companion to :func:`emit_json`. That one emits a single
    query's floor AST, which is all an engine needs to *find*; this emits the
    program -- statements, templates, the sentinel table -- which is what an
    engine needs to *run*. Both are pure data, so either can cross a process or
    a language boundary; only this one carries a whole script.

    A back-referencing factor rides the program as a late slot rather than
    being refused, since the format can express one -- but resolving a slot
    needs the compiler that emitted it, so a program carrying one executes only
    in this process.
    """
    return json.dumps(_encode_program(_compile_program(_to_ast, source, standard_library())))


__all__ = [
    "Entry",
    "HimarkScopeError",
    "HimarkSyntaxError",
    "Match",
    "MatchPart",
    "Query",
    "Universe",
    "emit_fragments",
    "emit_json",
    "emit_program",
    "finditer",
    "match",
    "parse",
    "run",
]
