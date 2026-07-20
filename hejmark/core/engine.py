"""Engine orchestration: wire a parser port to expansion, denotation and matching.

This module combines a parser adapter (injected via the :class:`ToAst` port)
with the L1.5 expander and core's ``denote`` and ``match``/``finditer``. The
adapter is never imported here -- it is passed in by the composition root (cli
/ library entry point), keeping the dependency arrow strictly inward.

The pipeline is one line long: source becomes a surface AST, the surface
expands into the floor's six constructors, and the floor denotes. Every layer
above the floor is gone before ``denote`` is called.
"""

from __future__ import annotations

from collections.abc import Iterator

from hejmark.core.floor.universe import denote
from hejmark.core.ports import ToAst
from hejmark.core.scan.match import Factor, Match, Query
from hejmark.core.scan.match import finditer as _finditer
from hejmark.core.scan.match import match as _match
from hejmark.core.std import std_env
from hejmark.core.surface.ast import Expr, HimarkScopeError, ScriptNode, Statement
from hejmark.core.surface.expand import Ctx, expand
from hejmark.core.surface.late import Late, reads
from hejmark.core.surface.resolve import Env, collect, merge, statements


def script(to_ast: ToAst, source: str) -> tuple[ScriptNode, Env]:
    """Parse *source* and resolve its declarations over the seeded std."""
    node = to_ast(source)
    return node, merge(std_env(to_ast), collect(node))


def query(expr: Expr, env: Env, source: str = "") -> Query:
    """Expand and denote one query expression into a :class:`Query`.

    A unit that back-references a factor to its left cannot expand yet; it
    enters the query as a :class:`Late`, expanded per attempt once the matcher
    has bound its reads. A read of the reading factor itself, of one to its
    right, or past the written factors has nothing to bind and is refused.

    Raises:
        HimarkScopeError: a read is not strictly left of the factor reading it.
    """
    factors: list[Factor] = []
    for index, unit in enumerate(expr.units):
        needs = reads(unit)
        past = [k for k in needs if k > index]
        if past:
            msg = f"${past[0]} reads factor {past[0]}, but only {index} factor(s) stand to its left"
            raise HimarkScopeError(msg)
        if needs:
            factors.append(Late(unit, env, needs))
        else:
            factors.append(denote(expand(Expr((unit,)), Ctx(env))[0]))
    return Query(source, tuple(factors))


def parse(to_ast: ToAst, source: str) -> Query:
    """Parse and denote *source* into a :class:`Query` (universes, most-significant-first).

    Raises:
        HimarkScopeError: *source* is not a single query expression.
    """
    node, env = script(to_ast, source)
    found = statements(node)
    if len(found) != 1 or not isinstance(found[0], Statement):
        msg = "expected a single query expression"
        raise HimarkScopeError(msg)
    only = found[0]
    if len(only.steps) != 1 or not isinstance(only.steps[0], Expr):
        msg = "expected a single query expression"
        raise HimarkScopeError(msg)
    return query(only.steps[0], env, source)


def _as_query(to_ast: ToAst, value: Query | str) -> Query:
    """Coerce raw source to a denoted query; pass an existing query through."""
    return parse(to_ast, value) if isinstance(value, str) else value


def match(to_ast: ToAst, value: Query | str, text: str, start: int = 0) -> Match | None:
    """Return the leftmost match of *value* in *text* at or after *start*."""
    return _match(_as_query(to_ast, value), text, start)


def finditer(to_ast: ToAst, value: Query | str, text: str) -> Iterator[Match]:
    """Yield non-overlapping matches of *value* across *text*, left to right."""
    return _finditer(_as_query(to_ast, value), text)
