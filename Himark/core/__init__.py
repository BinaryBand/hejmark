"""core: pure business logic, use-cases, and the port interfaces.

Bottom of the stack: no I/O and no imports from the other layers -- the
import-linter contract guarantees this. This package is a namespace shell --
logic lives in modules like core.main, never in this __init__.

Cross-layer interfaces live here as typing.Protocol classes, by convention in a
core/ports.py module you create when you add your first port. A port declares
the shape an adapter must satisfy, for example::

    from typing import Protocol

    class Clock(Protocol):
        def now(self) -> float: ...

The concrete implementation lives in adapters; cli -- the composition root --
constructs it and passes it into core's use-case functions, which accept ports
as parameters. Because core may not import adapters, the dependency always
points inward, and ty verifies structurally that each adapter satisfies its
port at the call site in cli.
"""

from __future__ import annotations
