"""Integration tests for the final segment (`{a..}`) and the transfinite engine.

These drive the public API end to end: parsing a final segment, denoting an
infinite universe symbolically, and matching it against finite text with ordinal
values. FOUNDATION.md's worked cases are pinned here.
"""

from __future__ import annotations

import pytest

from Himark import match, parse
from Himark.core.ordinal import OMEGA
from Himark.core.universe import HimarkInfiniteError


def test_final_segment_matches_the_longest_prefix() -> None:
    """``{a..}`` greedily consumes the longest prefix that sorts at or after ``a``."""
    found = match("{a..}", "hello world")
    assert found is not None
    assert found.span == (0, 11)


def test_final_segment_is_an_infinite_universe() -> None:
    """The universe has omega entries and refuses to materialize them."""
    universe = parse("{a..}").universes[0]
    assert universe.entry_count == OMEGA
    assert not universe.is_finite
    with pytest.raises(HimarkInfiniteError):
        _ = universe.entries


def test_bounded_range_is_the_difference_of_two_final_segments() -> None:
    """``{a..,!{b..}}`` denotes the bounded interval ``[a, b)`` -- just ``a``."""
    universe = parse("{a..,!{b..}}").universes[0]
    assert universe.entry_count == 1
    assert match("{a..,!{b..}}", "a") is not None
    assert match("{a..,!{b..}}", "b") is None


def test_union_after_a_final_segment_lands_at_omega() -> None:
    """``{b..,a}``: the run holds omega entries, so ``a`` follows at value omega."""
    universe = parse("{b..,a}").universes[0]
    assert universe.entry_count == OMEGA + 1
    found = match("{b..,a}", "a")
    assert found is not None
    assert found.value == OMEGA


def test_fold_over_a_final_segment_is_one_entry() -> None:
    """``{{a..}}`` folds unboundedly many faces into a single entry."""
    universe = parse("{{a..}}").universes[0]
    assert universe.entry_count == 1
    assert not universe.is_finite


def test_product_with_a_final_segment_yields_an_ordinal_value() -> None:
    """``{x,y}{a..}`` places a match at ``omega*m + n`` (base omega on the left)."""
    found = match("{x,y}{a..}", "yc")
    assert found is not None
    # y is entry 1 of {x,y}; c is at rank 2 in [a..) -> omega*1 + 2.
    assert found.value == OMEGA + 2


def test_reversed_range_stays_empty() -> None:
    """``{z..a}`` is the standard empty interval; emptiness never means unbounded."""
    assert parse("{z..a}").universes[0].entry_count == 0
    assert match("{z..a}", "abc") is None
