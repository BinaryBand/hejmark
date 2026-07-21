"""The Program IR is frozen, pure data: strings, ints, tuples, floor nodes."""

from __future__ import annotations

import pytest

from hejmark.core.floor.syntax import Face, UniverseNode
from hejmark.core.ir.program import (
    CapturePart,
    CompiledIter,
    CompiledQuery,
    CompiledStatement,
    CompiledTemplate,
    LateResolver,
    LateSlot,
    Program,
    Sentinel,
    SentinelPart,
    TextPart,
    noncharacter,
)


def _query() -> CompiledQuery:
    return CompiledQuery("{a}{$1}", (UniverseNode((Face("a"),)), LateSlot(0, (1,))))


def test_nodes_are_frozen() -> None:
    """IR nodes are immutable, so a payload can never be rewritten in place."""
    slot = LateSlot(0, (1,))
    with pytest.raises(AttributeError):
        slot.slot = 1  # ty: ignore[invalid-assignment]


def test_nodes_compare_by_value() -> None:
    """Two payloads spelling the same program are equal, which round-trips lean on."""
    assert _query() == _query()
    assert LateSlot(0, (1,)) != LateSlot(1, (1,))
    assert TextPart("a") != CapturePart("a")


def test_a_program_holds_statements_and_the_sentinel_table() -> None:
    """Statements stay in source order; sentinels ride as name-face pairs."""
    template = CompiledTemplate((TextPart("x"), CapturePart("$1"), SentinelPart("end")))
    line = CompiledStatement((_query(), template))
    contract = CompiledIter(_query(), "m", UniverseNode((Face("a"),)), template)
    program = Program((line, contract), (Sentinel("end", "﷐"),))
    assert program.statements == (line, contract)
    assert program.sentinels[0].face == "﷐"


def test_a_resolver_is_a_plain_callable() -> None:
    """The back edge is a value, not an import: any callable of the shape serves."""

    def resolve(_slot: int, reads: tuple[str, ...]) -> UniverseNode:
        return UniverseNode((Face(reads[0]),))

    resolver: LateResolver = resolve
    assert resolver(0, ("a",)) == UniverseNode((Face("a"),))


def test_noncharacters_span_the_block_and_every_plane_end() -> None:
    """The sentinel space is exactly Unicode's noncharacters."""
    assert noncharacter("﷐")
    assert noncharacter("﷯")
    assert noncharacter("￾")
    assert noncharacter("\U0010ffff")
    assert not noncharacter("a")
    assert not noncharacter("ﷰ")
