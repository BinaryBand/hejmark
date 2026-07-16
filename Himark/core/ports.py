"""core.ports: Protocol interfaces implemented by concrete adapters.

Declaring the shape here (rather than in adapters) is what lets core stay
import-free of adapters while cli still gets a structurally-checked contract
at the call site.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Protocol

if TYPE_CHECKING:
    from pathlib import Path


class ParserGenerator(Protocol):
    """Generates a parser from an ANTLR grammar file."""

    def generate(self, grammar: Path, output_dir: Path, *, language: str) -> None:
        """Generate *language* parser sources for *grammar* into *output_dir*."""
        ...
