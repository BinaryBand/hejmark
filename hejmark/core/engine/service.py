"""The in-process engine, as an :class:`~hejmark.core.ir.ports.Engine`.

A thin front on what ``engine/`` already does: :func:`execute.run` for whole
programs, and :func:`~hejmark.core.engine.denote.universe.canonical_faces` for
the bounded reads expansion needs. Nothing is implemented here -- the point is
that the engine now presents itself through the same shape an out-of-process
one will, so the driver names a port instead of a module and either substitutes
for the other.

This is also the reference implementation the conformance corpus is generated
from, and the one a ported engine is checked against.
"""

from __future__ import annotations

from collections.abc import Iterator

from hejmark.core.engine import execute
from hejmark.core.engine.denote.universe import canonical_faces
from hejmark.core.floor.syntax import UniverseNode
from hejmark.core.ir.program import LateResolver, Program


class InProcess:
    """The engine that runs here, in this interpreter, against live objects."""

    def run(self, program: Program, document: str, resolver: LateResolver) -> str:
        """Execute *program* against *document*; see :meth:`Engine.run`."""
        return execute.run(program, document, resolver)

    def canonical_faces(self, node: UniverseNode) -> Iterator[str]:
        """Stream *node*'s canonical faces; see :meth:`Engine.canonical_faces`."""
        return canonical_faces(node)
