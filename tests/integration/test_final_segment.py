"""Integration tests for the final segment (`{a..}`) and infinite universes.

These drive the public API end to end: parsing a final segment, denoting an
infinite universe symbolically, matching it against finite text, and streaming
its entries lazily. No entry is ever materialized wholesale.
"""

from __future__ import annotations

from itertools import islice

from Himark import match, parse


def test_final_segment_matches_the_longest_prefix() -> None:
    """``{a..}`` greedily consumes the longest prefix that sorts at or after ``a``."""
    found = match("{a..}", "hello world")
    assert found is not None
    assert found.span == (0, 11)


def test_final_segment_streams_without_materializing() -> None:
    """The universe is infinite; the lazy iterator walks it in spelling order."""
    universe = parse("{a..}").universes[0]
    assert [e.faces for e in islice(universe.entries(), 3)] == [("a",), ("b",), ("c",)]
    assert universe.contains("zzzz")
    assert not universe.contains("")


def test_bounded_range_is_the_difference_of_two_final_segments() -> None:
    """``{a..,!{b..}}`` denotes the bounded interval ``[a, b)`` -- just ``a``."""
    universe = parse("{a..,!{b..}}").universes[0]
    assert [e.faces for e in universe.entries()] == [("a",)]
    assert match("{a..,!{b..}}", "a") is not None
    assert match("{a..,!{b..}}", "b") is None


def test_union_after_a_final_segment_is_claimed_away() -> None:
    """``{b..,a}``: the run leaves ``a`` unclaimed, so it follows the whole run."""
    universe = parse("{b..,a}").universes[0]
    assert universe.contains("a")
    assert [e.faces for e in islice(universe.entries(), 2)] == [("b",), ("c",)]
    found = match("{b..,a}", "a")
    assert found is not None
    assert found.span == (0, 1)


def test_fold_over_a_final_segment_answers_membership() -> None:
    """``{{a..}}`` is one entry with unboundedly many faces; membership stays cheap."""
    universe = parse("{{a..}}").universes[0]
    assert universe.contains("hello")
    assert not universe.contains("\x00")


def test_reversed_range_stays_empty() -> None:
    """``{z..a}`` is the standard empty interval; emptiness never means unbounded."""
    assert [e.faces for e in parse("{z..a}").universes[0].entries()] == []
    assert match("{z..a}", "abc") is None
