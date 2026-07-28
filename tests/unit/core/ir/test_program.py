"""The Program IR is frozen, pure data: strings, ints, tuples, floor nodes."""

from __future__ import annotations

import pytest

from hejmark.core.floor.syntax import Face, UniverseNode
from hejmark.core.ir.program import (
    NONCHARACTER_RANGES,
    SENTINEL_POOL,
    CapturePart,
    CompiledIter,
    CompiledQuery,
    CompiledStatement,
    CompiledTemplate,
    EagerFactor,
    LateResolver,
    LateSlot,
    Program,
    TextPart,
    is_noncharacter,
)


def _query() -> CompiledQuery:
    eager = EagerFactor(UniverseNode((Face("a"),)))
    return CompiledQuery("{a}{$1}", (eager, LateSlot(0, (1,))))


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
    """Statements stay in source order; sentinels ride as bare faces to strip."""
    template = CompiledTemplate((TextPart("x"), CapturePart("$1")))
    line = CompiledStatement((_query(), template))
    contract = CompiledIter(_query(), template)
    program = Program((line, contract), ("﷐",))
    assert program.statements == (line, contract)
    assert program.sentinels[0] == "﷐"


def test_the_sentinel_pool_is_the_noncharacter_space_in_allocation_order() -> None:
    """The pool and the ranges are one definition seen twice, so they cannot drift.

    Whatever the allocator hands out, ``char`` must already have subtracted --
    otherwise a document could spell a mask. Order is ascending from U+FDD0, so
    allocation is deterministic and a script always masks the same way.
    """
    assert len(SENTINEL_POOL) == 66
    assert all(is_noncharacter(point) for point in SENTINEL_POOL)
    assert sorted(SENTINEL_POOL) == list(SENTINEL_POOL)
    assert SENTINEL_POOL[0] == 0xFDD0
    assert SENTINEL_POOL[-1] == 0x10FFFF
    covered = sum(high - low + 1 for low, high in NONCHARACTER_RANGES)
    assert covered == len(SENTINEL_POOL)


def test_a_resolver_is_a_plain_callable() -> None:
    """The back edge is a value, not an import: any callable of the shape serves."""

    def resolve(_slot: int, reads: tuple[str, ...]) -> UniverseNode:
        return UniverseNode((Face(reads[0]),))

    resolver: LateResolver = resolve
    assert resolver(0, ("a",)) == UniverseNode((Face("a"),))
