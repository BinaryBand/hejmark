"""The driver: wire a parser port through the compiler into the engine.

This module is the composition root and deliberately implements nothing. The
parser adapter arrives via the :class:`ToAst` port; the compiler lowers source
to a pure-data program (or a single compiled query) plus its late resolver;
the engine loads and runs it. Each seam it crosses is one the layers below may
not cross themselves -- the compiler and the engine never import each other,
and only the data defined in :mod:`hejmark.core.ir` passes between them.
"""

from __future__ import annotations

from collections.abc import Iterator

from hejmark.core.compiler.compile import compile_script, compile_single, script
from hejmark.core.compiler.ports import ToAst
from hejmark.core.engine import execute
from hejmark.core.engine.scan.match import Match, Query, load_query
from hejmark.core.engine.scan.match import finditer as _finditer
from hejmark.core.engine.scan.match import match as _match
from hejmark.core.ir.program import Program


def parse(to_ast: ToAst, source: str) -> Query:
    """Parse, compile and load *source* into a :class:`Query` ready to scan.

    Raises:
        HimarkScopeError: *source* is not a single query expression.
    """
    node, env = script(to_ast, source)
    compiled, resolver = compile_single(node, env, source)
    return load_query(compiled, resolver)


def _as_query(to_ast: ToAst, value: Query | str) -> Query:
    """Coerce raw source to a loaded query; pass an existing query through."""
    return parse(to_ast, value) if isinstance(value, str) else value


def match(to_ast: ToAst, value: Query | str, text: str, start: int = 0) -> Match | None:
    """Return the leftmost match of *value* in *text* at or after *start*."""
    return _match(_as_query(to_ast, value), text, start)


def finditer(to_ast: ToAst, value: Query | str, text: str) -> Iterator[Match]:
    """Yield non-overlapping matches of *value* across *text*, left to right."""
    return _finditer(_as_query(to_ast, value), text)


def run(to_ast: ToAst, source: str, document: str) -> str:
    """Compile a whole script and run it against *document*."""
    node, env = script(to_ast, source)
    program, resolver = compile_script(node, env)
    return execute.run(program, document, resolver)


def compile_program(to_ast: ToAst, source: str) -> Program:
    """Compile a whole script to its pure-data program, with no engine attached.

    The same first half :func:`run` performs, stopping where the data is: what
    comes back is serializable, so this is what a host in another process or
    another language reads to execute a script itself. The resolver -- the one
    back edge, and the one thing that is not data -- is dropped here, so a
    program carrying a late slot is one only an in-process engine can run.
    """
    node, env = script(to_ast, source)
    program, _resolver = compile_script(node, env)
    return program
