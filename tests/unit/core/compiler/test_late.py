"""Late-bound expansion: what a back-reference reads and how its slot resolves."""

from __future__ import annotations

import pytest

from hejmark import parse
from hejmark.core.compiler.ast import (
    PipeItem,
    Read,
    Ref,
    Segments,
    Unit,
    UniverseNode,
)
from hejmark.core.compiler.late import SlotTable, reads
from hejmark.core.engine.scan.match import Slot
from hejmark.core.floor.universe import Universe, denote
from hejmark.core.ir.errors import HimarkScopeError


def _slot(source: str, index: int = 1) -> Slot:
    """The slotted factor a back-referencing query carries at *index*."""
    factor = parse(source).universes[index]
    assert isinstance(factor, Slot)
    return factor


def _resolve(source: str, faces: tuple[str, ...], index: int = 1) -> Universe:
    """Resolve a query's slot through its own table -- faces in, floor node out."""
    slot = _slot(source, index)
    return denote(slot.resolver(slot.slot, faces))


def test_reads_finds_a_pattern_read() -> None:
    """A ``Read`` segment anywhere in the unit's brace tree is a read."""
    unit = Unit(UniverseNode((Segments((Read(1),)),)))
    assert reads(unit) == (1,)


def test_reads_finds_an_argument_read() -> None:
    """A pipeline argument spelling ``$k`` is a read; a stage name never is."""
    unit = Unit(Ref("d"), None, (PipeItem("where"), PipeItem("0", "$2")))
    assert reads(unit) == (2,)


def test_reads_is_written_order_without_duplicates() -> None:
    """The indices come back as written, each once."""
    unit = Unit(UniverseNode((Segments((Read(2), Read(1), Read(2))),)))
    assert reads(unit) == (2, 1)


def test_reads_never_crosses_a_name() -> None:
    """A read hides behind no reference: a spliced declaration contributes nothing."""
    assert reads(Unit(Ref("x"))) == ()


def test_resolve_substitutes_a_pattern_read_as_a_literal_face() -> None:
    """The bound face stands as the spelling it is, alongside the unit's own members."""
    universe = _resolve("{a,b}{x,$1}", ("b",))

    assert universe.contains("b")
    assert universe.contains("x")
    assert not universe.contains("a")


def test_resolve_substitutes_an_argument_read_under_the_binding_rules() -> None:
    """``where 0..$1`` binds the face canonicalized, so ``00`` cuts at value 0."""
    source = "{00,11}{0..9}[where 0..$1]"

    assert _resolve(source, ("00",)).contains("0")
    assert not _resolve(source, ("00",)).contains("1")
    assert _resolve(source, ("11",)).contains("11")


def test_resolve_reaches_a_read_inside_a_subtraction() -> None:
    """``!{$1}`` carves the bound face out, at any depth of the unit's tree."""
    source = "{ab}{a..zz,!{$1}}"

    assert _resolve(source, ("ab",)).contains("x")
    assert not _resolve(source, ("ab",)).contains("ab")


def test_resolve_takes_the_projected_reads_not_the_whole_binding() -> None:
    """The resolver receives one face per need: `$1` after two factors still takes one."""
    universe = _resolve("{a,b}{c}{$1}", ("a",), 2)
    assert universe.contains("a")
    assert not universe.contains("c")


def test_an_unknown_slot_id_is_refused() -> None:
    """The table answers only for slots it minted."""
    table = SlotTable()
    with pytest.raises(HimarkScopeError, match="unknown late slot"):
        table.resolve(7, ("a",))


def test_misaligned_reads_are_refused() -> None:
    """One face per need, exactly: the table never pads or drops."""
    slot = _slot("{a,b}{$1}")
    with pytest.raises(HimarkScopeError, match="reads 1 factor"):
        slot.resolver(slot.slot, ("a", "b"))
