"""The L2 seam: a ``Program -> Program`` pass, plus the ingest boundary guard."""

from __future__ import annotations

import pytest

from hejmark.core import contract
from hejmark.core.ir.errors import HimarkSentinelError
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
        (Sentinel("s", "\ufdd0"),),
    )
    result = contract.apply(program)
    assert result is program
    assert result.statements == program.statements
    assert result.sentinels == program.sentinels


def test_ingest_passes_a_clean_document() -> None:
    """A document of ordinary characters crosses the boundary silently."""
    assert contract.check_ingest("hello, world\n007,7 \U0001f600") is None


def test_ingest_refuses_a_document_spelling_a_block_noncharacter() -> None:
    """A U+FDD0-block noncharacter is the sentinel space, refused at ingest."""
    with pytest.raises(HimarkSentinelError, match=r"U\+FDD0"):
        contract.check_ingest("ab\ufdd0cd")


def test_ingest_refuses_the_plane_end_noncharacters() -> None:
    """The last two code points of every plane are noncharacters too, and refused."""
    for spelling in ("x\ufffey", "x\uffffy", "x\U0001fffey", "x\U0010ffffy"):
        with pytest.raises(HimarkSentinelError, match="noncharacter"):
            contract.check_ingest(spelling)


def test_ingest_allows_the_characters_bracketing_the_block() -> None:
    """U+FDCF and U+FDF0 bracket the block and are ordinary, admitted characters."""
    assert contract.check_ingest("\ufdcf\ufdf0") is None
