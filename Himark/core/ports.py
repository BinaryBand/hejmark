"""Ports: the Protocol interfaces that adapters must satisfy.

A port is defined here in core; its concrete implementation lives in adapters.
Because core may not import adapters, the dependency always points inward. The
composition root (cli and the library entry point) constructs concrete adapters
and passes them to core use-cases. ``ty`` verifies each adapter structurally
satisfies its port at the wiring site.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Protocol

if TYPE_CHECKING:
    from Himark.core.syntax import QueryNode


class ToAst(Protocol):
    """Callable that parses Himark source into a faithful AST."""

    def __call__(self, source: str) -> QueryNode:
        """Parse *source* into a :class:`QueryNode` AST."""
