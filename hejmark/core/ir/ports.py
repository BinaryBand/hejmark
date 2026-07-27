"""core.ir.ports: the engine, as a shape rather than an import.

An engine is whatever answers the verbs in ``docs/protocol.md``. Declaring that
here -- beside the payload it consumes and the two callbacks it exchanges --
is what lets :mod:`hejmark.core.driver` reach an engine without naming one, so
an out-of-process implementation substitutes for the in-process one without a
line changing above it.

The two verbs are exactly the protocol's, and both traffic in pure data:
:meth:`Engine.run` executes a whole :class:`~hejmark.core.ir.program.Program`,
and :meth:`Engine.canonical_faces` answers the bounded denotation reads that
expansion is defined by (``@0`` and value cuts). The late resolver rides
``run`` as an argument rather than being stored, because it belongs to the
compilation that produced the program, not to the engine.

Scanning a single query -- :func:`hejmark.parse` and friends -- is deliberately
*not* here. That surface hands back a live denoted universe for a caller to
inspect, which is an in-process capability rather than an engine contract; the
protocol has no verb for it. An engine that should serve it too needs the
query-handle question answered first (an opaque handle the host cannot inspect,
or a recompile per scan).
"""

from __future__ import annotations

from collections.abc import Iterator
from typing import Protocol

from hejmark.core.floor.syntax import UniverseNode
from hejmark.core.ir.program import LateResolver, Program


class Engine(Protocol):
    """What the driver needs from an engine, in or out of this process."""

    def run(self, program: Program, document: str, resolver: LateResolver) -> str:
        """Execute *program* against *document*, returning the spliced result.

        Statements run in source order and each declared sentinel face is
        cleared from the result. *resolver* expands a back-referencing factor
        once its reads bind; a slot-free program never calls it.
        """
        ...

    def canonical_faces(self, node: UniverseNode) -> Iterator[str]:
        """Stream the canonical face of each entry of *node*, in declaration order.

        The engine's side of :data:`~hejmark.core.ir.program.ToFaces`. Lazy by
        contract: a caller wanting only the zero entry must pay for one entry,
        since a universe may denote unboundedly many.
        """
        ...
