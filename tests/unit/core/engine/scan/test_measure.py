"""The measure comparator: entry order decided structurally, never by streaming."""

from __future__ import annotations

import pytest

from hejmark import parse
from hejmark.core.engine.scan.measure import precedes
from hejmark.core.floor.universe import Universe
from hejmark.core.ir.errors import HimarkScopeError


def _universe(source: str) -> Universe:
    """Denote a single-factor query's universe."""
    return parse(source).universe()


def test_union_order_is_member_major() -> None:
    """Entries stream in declaration order, so the written order is the order."""
    universe = _universe("{z, a}")
    assert precedes(universe, "z", "a")
    assert not precedes(universe, "a", "z")


def test_window_order_is_spelling_order() -> None:
    """Inside a range, shortlex is the order, as everywhere on the spelling axis."""
    universe = _universe("{a..z}")
    assert precedes(universe, "b", "c")
    assert not precedes(universe, "c", "b")


def test_faces_of_one_entry_are_nowhere_earlier() -> None:
    """A fold is one entry, so re-spelling it is no descent in either direction."""
    universe = _universe("{{cat,feline}}")
    assert not precedes(universe, "cat", "feline")
    assert not precedes(universe, "feline", "cat")


def test_product_order_runs_leftmost_slowest() -> None:
    """The most significant factor moves slowest, so the order is lex by factor."""
    universe = _universe("{ {a,b}{c,d} }")
    assert precedes(universe, "ac", "ad")
    assert precedes(universe, "ad", "bc")
    assert not precedes(universe, "bc", "ad")


def test_closure_order_is_stage_major() -> None:
    """A later stage sits after every entry of an earlier one, however spelled."""
    universe = _universe("{a, &a}")
    assert precedes(universe, "a", "aa")
    assert precedes(universe, "aa", "aaa")
    assert not precedes(universe, "aaa", "aa")


def test_value_order_beats_spelling_order() -> None:
    """The value line orders `9` before `10`; raw shortlex would not."""
    universe = _universe("{0..9}[numerals padfree]")
    assert precedes(universe, "9", "10")
    assert not precedes(universe, "10", "9")


def test_paddings_of_one_value_are_one_entry() -> None:
    """`padfree` hangs every padding on the value's entry, so `05` sits at 5."""
    universe = _universe("{0..9}[numerals padfree]")
    assert not precedes(universe, "05", "5")
    assert not precedes(universe, "5", "05")
    assert precedes(universe, "05", "9")


def test_a_subtraction_moves_the_owner_rightward() -> None:
    """A face stripped from the run belongs to the member that re-adds it."""
    universe = _universe("{a..c, !{b}, b}")
    assert precedes(universe, "c", "b")
    assert not precedes(universe, "b", "c")


def test_a_spelling_the_universe_does_not_wear_is_refused() -> None:
    """Order is asked only of members; anything else is a scope error."""
    with pytest.raises(HimarkScopeError, match="does not spell"):
        precedes(_universe("{a}"), "z", "a")
