"""The driver: wire a parser port through the compiler into the engine.

This module is the composition root and deliberately implements nothing. The
parser adapter arrives via the :class:`ToAst` port; the compiler lowers source
to a pure-data program (or a single compiled query) plus its late resolver; the
L2 contract (:mod:`hejmark.core.contract`) intercepts that program on its way to
execution; and the engine loads and runs it. Each seam it crosses is one the
layers below may not cross themselves -- the compiler, the contract and the
engine never import each other, and only the data defined in
:mod:`hejmark.core.ir` passes between them.

Both callbacks over that seam are wired here, one in each direction. The
engine's ``canonical_faces`` goes *in* as the compiler's
:data:`~hejmark.core.ir.program.ToFaces`, which is how expansion reads a
denotation without importing one; the compiler's late resolver comes *out* with
the program, which is how the engine expands a back-reference without importing
the expander.

The engine itself arrives as the :class:`~hejmark.core.ir.ports.Engine` port,
the same way the parser arrives as :class:`ToAst`, so nothing here names a
concrete engine and an out-of-process one substitutes without a change above.
The one exception is :func:`parse` and the scans built on it: those hand back a
live denoted :class:`Query` for the caller to inspect, which is an in-process
capability rather than an engine verb, so they still reach for the local
scanner. ``docs/protocol.md`` says why the protocol has no verb for it.
"""

from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass

from hejmark.core import contract
from hejmark.core.compiler.compile import compile_script, compile_single, script
from hejmark.core.compiler.ports import ToAst
from hejmark.core.engine.scan.match import Match, Query, load_query
from hejmark.core.engine.scan.match import finditer as _finditer
from hejmark.core.engine.scan.match import match as _match
from hejmark.core.ir.ports import Engine
from hejmark.core.ir.program import Program


@dataclass(frozen=True)
class Adapters:
    """The concrete pieces a run is composed from: a parser, and an engine.

    Both arrive as ports (:class:`ToAst`, :class:`~hejmark.core.ir.ports.Engine`)
    and travel together, because every entry point below needs both and neither
    may be reached by import from here. Concrete implementations live in
    ``hejmark/adapters/`` and, for the engine that runs in this interpreter,
    :class:`hejmark.core.engine.service.InProcess`.
    """

    to_ast: ToAst
    engine: Engine


def parse(adapters: Adapters, source: str, prelude: str | None = None) -> Query:
    """Parse, compile and load *source* into a :class:`Query` ready to scan.

    In-process only: the query it returns holds live denoted universes, which
    is what lets a caller inspect them and what an out-of-process engine cannot
    hand back. *engine* supplies the denotation expansion reads, not the scan.

    Raises:
        HimarkScopeError: *source* is not a single query expression.
    """
    node, env = script(adapters.to_ast, source, prelude)
    compiled, resolver = compile_single(adapters.engine.canonical_faces, node, env, source)
    return load_query(compiled, resolver)


def _as_query(adapters: Adapters, value: Query | str, prelude: str | None) -> Query:
    """Coerce raw source to a loaded query; pass an existing query through."""
    return parse(adapters, value, prelude) if isinstance(value, str) else value


def match(
    adapters: Adapters, value: Query | str, text: str, start: int = 0, prelude: str | None = None
) -> Match | None:
    """Return the leftmost match of *value* in *text* at or after *start*."""
    return _match(_as_query(adapters, value, prelude), text, start)


def finditer(
    adapters: Adapters, value: Query | str, text: str, prelude: str | None = None
) -> Iterator[Match]:
    """Yield non-overlapping matches of *value* across *text*, left to right."""
    return _finditer(_as_query(adapters, value, prelude), text)


def run(adapters: Adapters, source: str, document: str, prelude: str | None = None) -> str:
    """Compile a whole script and hand it to *engine* to run against *document*."""
    node, env = script(adapters.to_ast, source, prelude)
    program, resolver = compile_script(adapters.engine.canonical_faces, node, env)
    program = contract.apply(program)
    contract.check_ingest(document)
    return adapters.engine.run(program, document, resolver)


def compile_program(adapters: Adapters, source: str, prelude: str | None = None) -> Program:
    """Compile a whole script to its pure-data program, with no engine attached.

    The same first half :func:`run` performs, stopping where the data is: what
    comes back is serializable, so this is what a host in another process or
    another language reads to execute a script itself. The resolver -- the one
    back edge, and the one thing that is not data -- is dropped here, so a
    program carrying a late slot is one only an in-process engine can run.

    The contract runs here as it does in :func:`run`, so a program handed to
    another engine is the same program this one would execute. The L2 rewrites
    are the host's to perform, not the engine's to reproduce: an engine that
    knows nothing of them still receives their result.
    """
    node, env = script(adapters.to_ast, source, prelude)
    program, _resolver = compile_script(adapters.engine.canonical_faces, node, env)
    return contract.apply(program)
