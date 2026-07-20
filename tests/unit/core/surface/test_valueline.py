"""The value family's digit-walk: cutting the value line by position, not by spelling."""

import itertools

import pytest

from hejmark.core.floor import syntax
from hejmark.core.floor.universe import denote
from hejmark.core.surface.valueline import (
    RADIX_BUDGET,
    ValueLineError,
    cut,
    digits,
    value_of,
)

DECIMAL = syntax.UniverseNode((syntax.Range("0", "9"),))
# A non-character radix: the digit at value 1 wears a two-character face, so
# value order and shortlex part company over its numerals.
WIDE = syntax.UniverseNode((syntax.Face("a"), syntax.Face("bb")))
LETTERS = syntax.UniverseNode((syntax.Range("a", "z"),))
INFINITE = syntax.UniverseNode((syntax.Final("a"),))


def faces(node: syntax.UniverseNode, limit: int = 200) -> list[str]:
    """The canonical faces a cut denotes, in entry order."""
    return [entry.faces[0] for entry in itertools.islice(denote(node).entries(), limit)]


def test_digits_reads_the_radix_in_value_order() -> None:
    assert digits(DECIMAL) == tuple("0123456789")
    assert digits(WIDE) == ("a", "bb")


def test_digits_refuses_an_unbounded_head() -> None:
    with pytest.raises(ValueLineError, match=str(RADIX_BUDGET)):
        digits(INFINITE)


def test_value_of_reads_a_numeral_in_the_head_radix() -> None:
    assert value_of("0", digits(DECIMAL)) == 0
    assert value_of("12", digits(DECIMAL)) == 12
    # Leading zero digits strip: canonicalization falls out of positional value.
    assert value_of("007", digits(DECIMAL)) == 7
    assert value_of("aa", digits(LETTERS)) == 0


def test_value_of_splits_a_non_character_radix() -> None:
    alphabet = digits(WIDE)
    assert value_of("a", alphabet) == 0
    assert value_of("bb", alphabet) == 1
    assert value_of("bba", alphabet) == 2
    assert value_of("bbbb", alphabet) == 3


def test_value_of_refuses_a_numeral_the_radix_does_not_spell() -> None:
    with pytest.raises(ValueLineError, match="not a numeral"):
        value_of("7", digits(WIDE))


def test_cut_takes_a_bounded_stretch_of_the_value_line() -> None:
    assert faces(cut(DECIMAL, "8", "12")) == ["8", "9", "10", "11", "12"]
    assert faces(cut(DECIMAL, "99", "101")) == ["99", "100", "101"]


def test_cut_keeps_zero_wherever_the_range_reaches_it() -> None:
    assert faces(cut(DECIMAL, "0", "0")) == ["0"]
    assert faces(cut(DECIMAL, "0", "3")) == ["0", "1", "2", "3"]


def test_cut_is_total_in_the_floors_manner() -> None:
    # A high bound below the low one reads as the empty universe, not an error.
    assert faces(cut(DECIMAL, "5", "3")) == []
    assert faces(cut(syntax.UniverseNode(()), "0", "0")) == []


def test_cut_is_exact_over_a_non_character_radix() -> None:
    """The case a spelling range gets wrong: shortlex and value order disagree."""
    assert faces(cut(WIDE, "a", "bbbb")) == ["a", "bb", "bba", "bbbb"]
    assert faces(cut(WIDE, "bb", "bba")) == ["bb", "bba"]


def test_cut_never_leans_on_shortlex() -> None:
    """`bba` (value 2) sorts before `bb` under no shortlex reading of the cut.

    Shortlex would place the shorter `bb` first and then compare code points,
    which happens to agree here; what it cannot do is stop at value 2 without
    also admitting `bbb`, a spelling the radix does not spell as a numeral.
    """
    admitted = faces(cut(WIDE, "a", "bba"))
    assert admitted == ["a", "bb", "bba"]
    assert "bbb" not in admitted


def test_cut_spans_a_width_boundary_over_letters() -> None:
    # `aa` canonicalizes to `a`, value 0, so the width-1 numerals enter.
    assert len(faces(cut(LETTERS, "aa", "cc"))) == 55
