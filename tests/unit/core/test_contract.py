"""The L2 seam: a ``Program -> Program`` pass, plus the ingest boundary guard."""

from __future__ import annotations

import pytest

from hejmark.core import contract
from hejmark.core.floor.syntax import Face, Product, Range, Subtract, UniverseNode
from hejmark.core.ir.errors import HimarkSentinelError
from hejmark.core.ir.program import (
    CompiledQuery,
    CompiledStatement,
    CompiledTemplate,
    EagerFactor,
    LateSlot,
    Program,
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
        ("\ufdd0",),
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


def _factor(node: UniverseNode) -> Program:
    """A one-statement program whose only query factor is *node*."""
    query = CompiledQuery("q", (EagerFactor(node),))
    return Program((CompiledStatement((query,)),), ())


def _rewritten(node: UniverseNode) -> UniverseNode:
    """The universe *node* becomes after crossing the seam."""
    statement = contract.apply(_factor(node)).statements[0]
    assert isinstance(statement, CompiledStatement)
    step = statement.steps[0]
    assert isinstance(step, CompiledQuery)
    factor = step.factors[0]
    assert isinstance(factor, EagerFactor)
    return factor.node


def test_a_wrapped_range_sheds_its_wrapper() -> None:
    """`{a..z}[where c..g]` reaches the engine as `{c..g}`, not a product around one.

    Adjacency is the product, so the expander gives every pipeline stage a
    one-factor product to sit in. A product of one factor wears exactly that
    factor's faces in that factor's order, so looking through it is reading the
    same universe.
    """
    wrapped = UniverseNode((Product((UniverseNode((Range("c", "g"),)),)),))
    assert _rewritten(wrapped) == UniverseNode((Range("c", "g"),))


def test_a_top_exclusive_cut_folds_to_one_range() -> None:
    """L3's `below` is `{@lo..hi,!{@hi..hi}}`; here that becomes `{3..6}`.

    The compiler cannot see the pair -- each half is a separate cut, lowered on
    its own -- so this is the half of the value-cut collapse that needs the whole
    program in hand.
    """
    node = UniverseNode((Range("3", "7"), Subtract(UniverseNode((Range("7", "7"),)))))
    assert _rewritten(node) == UniverseNode((Range("3", "6"),))


def test_a_cut_off_the_bottom_folds_the_other_way() -> None:
    """Symmetric: stripping a prefix of the range leaves the rest of the range."""
    node = UniverseNode((Range("a", "z"), Subtract(UniverseNode((Range("a", "c"),)))))
    assert _rewritten(node) == UniverseNode((Range("d", "z"),))


def test_a_cut_that_swallows_the_range_leaves_nothing() -> None:
    """An empty result is a real answer, not a shape to leave alone."""
    node = UniverseNode((Range("c", "e"), Subtract(UniverseNode((Range("a", "z"),)))))
    assert _rewritten(node) == UniverseNode(())


def test_a_strip_through_the_middle_is_left_for_the_engine() -> None:
    """Two intervals are no single range, so the rewrite declines rather than guess.

    Partial in the same way `window.carve` is: a missed rewrite costs computation
    and never correctness, and the engine still carves this face by face.
    """
    node = UniverseNode((Range("a", "z"), Subtract(UniverseNode((Range("m", "p"),)))))
    assert _rewritten(node) == node


def test_a_strip_that_misses_entirely_is_left_alone() -> None:
    """Nothing overlaps, so there is nothing to fold -- the node passes through."""
    node = UniverseNode((Range("a", "e"), Subtract(UniverseNode((Range("x", "z"),)))))
    assert _rewritten(node) == node


def test_the_rewrite_reaches_a_nested_universe() -> None:
    """It is a whole-program pass, so a cut inside a product folds too."""
    inner = UniverseNode((Range("3", "7"), Subtract(UniverseNode((Range("7", "7"),)))))
    node = UniverseNode((Product((inner, UniverseNode((Face("x"),)))),))
    folded = UniverseNode((Range("3", "6"),))
    assert _rewritten(node) == UniverseNode((Product((folded, UniverseNode((Face("x"),)))),))


def test_a_late_slot_crosses_untouched() -> None:
    """A slot's universe does not exist yet, so there is nothing here to rewrite."""
    program = Program((CompiledStatement((CompiledQuery("q", (LateSlot(0, (1,)),)),)),), ())
    assert contract.apply(program) is program
