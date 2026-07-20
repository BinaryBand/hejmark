"""Late-bound expansion: what a back-reference reads and how it substitutes."""

from __future__ import annotations

from hejmark import parse
from hejmark.core.surface.ast import PipeItem, Read, Ref, Segments, Unit, UniverseNode
from hejmark.core.surface.late import Late, reads


def _late(source: str, index: int = 1) -> Late:
    """The late factor a back-referencing query carries at *index*."""
    factor = parse(source).universes[index]
    assert isinstance(factor, Late)
    return factor


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


def test_at_substitutes_a_pattern_read_as_a_literal_face() -> None:
    """The bound face stands as the spelling it is, alongside the unit's own members."""
    late = _late("{a,b}{x,$1}")
    universe = late.at(("b",))

    assert universe.contains("b")
    assert universe.contains("x")
    assert not universe.contains("a")


def test_at_substitutes_an_argument_read_under_the_binding_rules() -> None:
    """``where 0..$1`` binds the face canonicalized, so ``00`` cuts at value 0."""
    late = _late("{00,11}{0..9}[where 0..$1]")

    assert late.at(("00",)).contains("0")
    assert not late.at(("00",)).contains("1")
    assert late.at(("11",)).contains("11")


def test_at_reaches_a_read_inside_a_subtraction() -> None:
    """``!{$1}`` carves the bound face out, at any depth of the unit's tree."""
    late = _late("{ab}{a..zz, !{$1}}")

    assert late.at(("ab",)).contains("x")
    assert not late.at(("ab",)).contains("ab")


def test_at_memoizes_on_the_faces_it_needs() -> None:
    """Two bindings agreeing on the read faces resolve to the same universe."""
    late = _late("{a,b}{c}{$1}", 2)
    assert late.at(("a", "c")) is late.at(("a", "c"))
