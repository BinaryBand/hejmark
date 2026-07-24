"""The north-star table, executable: L1_TEMP.md's denotation rows, end to end.

Each row parses real source and asserts the denoted entries as face tuples --
the whole universe for finite rows, a prefix through the lazy iterator for
infinite ones. A row written as a top-level product is wrapped in one more
brace pair so it denotes as a product member (where the collision rule lives).
This file is the lockstep bridge between the spec's table and the code; a row
changed there should change here in the same commit.
"""

from __future__ import annotations

from itertools import islice

import pytest

from hejmark import parse

Faces = list[tuple[str, ...]]

# Finite rows: expression -> every entry, as its full face tuple in order.
FINITE: dict[str, Faces] = {
    "{a,b,c}": [("a",), ("b",), ("c",)],
    "{a..z}": [(c,) for c in "abcdefghijklmnopqrstuvwxyz"],
    "{{cat,feline}}": [("cat", "feline")],
    "{a..z,!{a,e,i,o,u}}": [(c,) for c in "bcdfghjklmnpqrstvwxyz"],
    "{{cat,feline},!{feline}}": [("cat",)],
    "{cat}{dog}": [("catdog",)],
    "{{a,ab}{b,c}}": [("ab",), ("ac",), ("abb",), ("abc",)],
    "{{a,ab}{c,bc}}": [("ac",), ("abc",), ("abbc",)],
    "{a,!{a}}": [],
    "{z..a}": [],
    "{{}}": [("",)],
    "{{{},0}}": [("", "0")],
    "{{{},0}}{{{},0}}": [("", "0", "00")],
    "{{{},0}}{0..9}": [(d, "0" + d) for d in "0123456789"],
    "{{{},0}}{0,00}": [("0", "00"), ("000",)],
    "{&}": [],
    "{a,&}": [("a",)],
}

# Infinite rows: expression -> a prefix of the entries, in declaration order.
PREFIX: dict[str, Faces] = {
    "{a..}": [("a",), ("b",), ("c",), ("d",)],
    "{a..}{b}": [("ab",), ("bb",), ("cb",)],
    "{b,c}{a..}": [("ba",), ("bb",), ("bc",)],
    "{b}{a..}{b}{a..}": [("baba",), ("babb",), ("babc",)],
    "{a,&{b}}": [("a",), ("ab",), ("abb",), ("abbb",)],
    "{ab,{a}&{b}}": [("ab",), ("aabb",), ("aaabbb",)],
    "{0,{1..9,&{0..9}}}": [(str(n),) for n in range(14)],
    "{a..,!{&}}": [("a",), ("b",), ("c",)],
    "{a,{{{},0}}&}": [("a",), ("0a",), ("00a",), ("000a",)],
    "{ab,&&}": [("ab",), ("abab",), ("ababab",)],
    r"{{\(}{b}{a..}{\)},{\(}&&{\)}}": [("(ba)",), ("(bb)",), ("(bc)",)],
}


def _entry_faces(source: str):
    """Denote *source* as one universe, wrapping a top-level product as a member."""
    if len(parse(source).universes) > 1:
        source = "{" + source + "}"
    universe = parse(source).universe()
    return (entry.faces for entry in universe.entries())


@pytest.mark.parametrize(("source", "expected"), FINITE.items(), ids=FINITE)
def test_finite_row_denotes_exactly(source: str, expected: Faces) -> None:
    """A finite north-star row denotes to exactly its listed entries."""
    assert list(_entry_faces(source)) == expected


@pytest.mark.parametrize(("source", "expected"), PREFIX.items(), ids=PREFIX)
def test_infinite_row_denotes_lazily(source: str, expected: Faces) -> None:
    """An infinite north-star row streams its listed prefix in order."""
    assert list(islice(_entry_faces(source), len(expected))) == expected


def test_spelling_order_is_generated_not_postulated() -> None:
    """`{{{}},&C}` over a tiny C yields every spelling in shortlex."""
    universe = parse("{{{}},&{a..b}}").universe()
    prefix = [entry.faces[0] for entry in islice(universe.entries(), 7)]
    assert prefix == ["", "a", "b", "aa", "ab", "ba", "bb"]


def test_closure_admission_witness_is_not_regular() -> None:
    """`{ab,{a}&{b}}` decides a^n b^n exactly -- membership, not enumeration."""
    universe = parse("{ab,{a}&{b}}").universe()
    assert universe.contains("a" * 7 + "b" * 7)
    assert not universe.contains("a" * 7 + "b" * 6)
    assert not universe.contains("ba")
