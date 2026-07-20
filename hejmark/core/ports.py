"""core.ports: Protocol interfaces implemented by concrete adapters.

Declaring the shape here (rather than in adapters) is what lets core stay
import-free of adapters while cli still gets a structurally-checked contract
at the call site.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Protocol

if TYPE_CHECKING:
    from collections.abc import Sequence
    from pathlib import Path

    from hejmark.core.syntax import ScriptNode


class ParserGenerator(Protocol):
    """Generates a parser from ANTLR grammar files."""

    def generate(self, grammars: Sequence[Path], output_dir: Path, *, language: str) -> None:
        """Generate *language* parser sources for *grammars* into *output_dir*."""
        ...


class ToAst(Protocol):
    """Callable that parses hejmark source into a faithful AST."""

    def __call__(self, source: str) -> ScriptNode:
        """Parse *source* into a :class:`ScriptNode` AST."""
        ...
