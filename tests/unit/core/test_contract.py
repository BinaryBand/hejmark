"""The L2 seam: a ``Program -> Program`` pass that is, today, the identity."""

from __future__ import annotations

from hejmark.core import contract
from hejmark.core.ir.program import (
    CompiledStatement,
    CompiledTemplate,
    Program,
    Sentinel,
    TextPart,
)


def test_the_seam_returns_an_empty_program_unchanged() -> None:
    """The contract is the identity: the same object comes back, nothing added."""
    program = Program((), ())
    assert contract.apply(program) is program


def test_the_seam_leaves_a_populated_program_untouched() -> None:
    """Statements and sentinels cross the seam exactly as compiled -- no rewrite."""
    program = Program(
        (CompiledStatement((CompiledTemplate((TextPart("x"),)),)),),
        (Sentinel("s", "﷐"),),
    )
    result = contract.apply(program)
    assert result is program
    assert result.statements == program.statements
    assert result.sentinels == program.sentinels
