"""The value family's digit-walk: cutting the value line by position, not by spelling."""

import itertools

import pytest

from hejmark.core.compiler.valueline import (
    ValueLineError,
    cut,
    digits,
    value_of,
)
from hejmark.core.engine.denote.universe import canonical_faces, denote
from hejmark.core.floor import syntax

DECIMAL = syntax.UniverseNode((syntax.Range("0", "9"),))
# A non-character radix: the digit at value 1 wears a two-character face, so
# value order and shortlex part company over its numerals.
WIDE = syntax.UniverseNode((syntax.Face("a"), syntax.Face("bb")))
LETTERS = syntax.UniverseNode((syntax.Range("a", "z"),))


def faces(node: syntax.UniverseNode, limit: int = 200) -> list[str]:
    """The canonical faces a cut denotes, in entry order."""
    return [entry.faces[0] for entry in itertools.islice(denote(node).entries(), limit)]


def test_digits_reads_the_radix_in_value_order() -> None:
    assert digits(canonical_faces, DECIMAL) == tuple("0123456789")
    assert digits(canonical_faces, WIDE) == ("a", "bb")


def test_value_of_reads_a_numeral_in_the_head_radix() -> None:
    assert value_of("0", digits(canonical_faces, DECIMAL)) == 0
    assert value_of("12", digits(canonical_faces, DECIMAL)) == 12
    # Leading zero digits strip: canonicalization falls out of positional value.
    assert value_of("007", digits(canonical_faces, DECIMAL)) == 7
    assert value_of("aa", digits(canonical_faces, LETTERS)) == 0


def test_value_of_splits_a_non_character_radix() -> None:
    alphabet = digits(canonical_faces, WIDE)
    assert value_of("a", alphabet) == 0
    assert value_of("bb", alphabet) == 1
    assert value_of("bba", alphabet) == 2
    assert value_of("bbbb", alphabet) == 3


def test_value_of_refuses_a_numeral_the_radix_does_not_spell() -> None:
    with pytest.raises(ValueLineError, match="not a numeral"):
        value_of("7", digits(canonical_faces, WIDE))


def test_cut_takes_a_bounded_stretch_of_the_value_line() -> None:
    assert faces(cut(canonical_faces, DECIMAL, "8", "12")) == ["8", "9", "10", "11", "12"]
    assert faces(cut(canonical_faces, DECIMAL, "99", "101")) == ["99", "100", "101"]


def test_cut_keeps_zero_wherever_the_range_reaches_it() -> None:
    assert faces(cut(canonical_faces, DECIMAL, "0", "0")) == ["0"]
    assert faces(cut(canonical_faces, DECIMAL, "0", "3")) == ["0", "1", "2", "3"]


def test_cut_is_total_in_the_floors_manner() -> None:
    # A high bound below the low one reads as the empty universe, not an error.
    assert faces(cut(canonical_faces, DECIMAL, "5", "3")) == []
    assert faces(cut(canonical_faces, syntax.UniverseNode(()), "0", "0")) == []


def test_cut_is_exact_over_a_non_character_radix() -> None:
    """The case a spelling range gets wrong: shortlex and value order disagree."""
    assert faces(cut(canonical_faces, WIDE, "a", "bbbb")) == ["a", "bb", "bba", "bbbb"]
    assert faces(cut(canonical_faces, WIDE, "bb", "bba")) == ["bb", "bba"]


def test_cut_never_leans_on_shortlex() -> None:
    """`bba` (value 2) sorts before `bb` under no shortlex reading of the cut.

    Shortlex would place the shorter `bb` first and then compare code points,
    which happens to agree here; what it cannot do is stop at value 2 without
    also admitting `bbb`, a spelling the radix does not spell as a numeral.
    """
    admitted = faces(cut(canonical_faces, WIDE, "a", "bba"))
    assert admitted == ["a", "bb", "bba"]
    assert "bbb" not in admitted


def test_cut_spans_a_width_boundary_over_letters() -> None:
    # `aa` canonicalizes to `a`, value 0, so the width-1 numerals enter.
    assert len(faces(cut(canonical_faces, LETTERS, "aa", "cc"))) == 55


def test_a_single_digit_cut_collapses_to_a_range() -> None:
    """L2's value-cut collapse: where value order and shortlex agree, a cut is a range.

    The digit-walk would say the same thing as a union of numerals with another
    union subtracted; over consecutive single-code-point digits it is one range,
    and saying so is a rewrite rather than a shortcut -- the entries are
    identical either way.
    """
    node = cut(canonical_faces, DECIMAL, "3", "7")
    assert node == syntax.UniverseNode((syntax.Range("3", "7"),))
    assert faces(node) == list("34567")


def test_the_collapse_holds_over_any_contiguous_radix() -> None:
    """Nothing here is about decimal: `a..z` cut `c..g` is `{c..g}` on the same rule."""
    assert cut(canonical_faces, LETTERS, "c", "g") == syntax.UniverseNode((syntax.Range("c", "g"),))


def test_a_wide_faced_radix_does_not_collapse() -> None:
    """The premise is checked, not assumed: a two-character digit is no range.

    `WIDE`'s digit at value 1 wears `bb`, so its numerals in value order are not
    an interval of the code space and the walk has to stand. Collapsing anyway
    would silently denote something else.
    """
    node = cut(canonical_faces, WIDE, "a", "bb")
    assert node != syntax.UniverseNode((syntax.Range("a", "bb"),))
    assert faces(node) == ["a", "bb"]


def test_a_multi_digit_cut_does_not_collapse() -> None:
    """Past the radix the numerals are products, and no single range spells those."""
    node = cut(canonical_faces, DECIMAL, "8", "12")
    assert faces(node) == ["8", "9", "10", "11", "12"]
    assert not any(isinstance(m, syntax.Range) for m in node.members)


def test_a_non_contiguous_radix_does_not_collapse() -> None:
    """Single code points are not enough -- they must also be adjacent ones.

    `{a,c,e}` cut across its whole span is three faces with gaps between them, so
    a range over `a..e` would wear `b` and `d` that the radix never declared.
    """
    sparse = syntax.UniverseNode((syntax.Face("a"), syntax.Face("c"), syntax.Face("e")))
    assert faces(cut(canonical_faces, sparse, "a", "e")) == ["a", "c", "e"]


def test_an_unbounded_head_is_refused_rather_than_read_forever() -> None:
    """L2's digit budget: a value cut needs a radix, and an unbounded head has none.

    Reading the bound means knowing every digit's position, so there is no
    partial answer to give. The head here streams without end, and the point of
    the budget is that this returns at all.
    """
    unbounded = syntax.UniverseNode(
        (
            syntax.Face("0"),
            syntax.Product((syntax.Closure(), syntax.UniverseNode((syntax.Range("0", "9"),)))),
        )
    )
    with pytest.raises(ValueLineError, match="bounded radix"):
        digits(canonical_faces, unbounded)
