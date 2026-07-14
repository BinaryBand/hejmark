"""Tests for core.order: the shortlex spelling order and symbolic interval sets.

The index/successor/inverse trio must realize one well-order of type omega, and
``IntervalSet`` must agree with brute-force Python set operations over a tiny
alphabet where every operation can be checked exhaustively.
"""

from __future__ import annotations

from hypothesis import given
from hypothesis.strategies import lists, text

from Himark.core.order import (
    IntervalSet,
    spelling_from_index,
    spelling_index,
    spelling_key,
    successor,
)

# A tiny alphabet whose short strings can be enumerated and checked exhaustively.
_ALPHABET = "abc"
_SMALL = text(alphabet=_ALPHABET, min_size=1, max_size=3)


def _universe_of_strings() -> list[str]:
    """Every non-empty string of length <= 3 over the tiny alphabet, in shortlex order."""
    strings = [*_ALPHABET]
    strings += [a + b for a in _ALPHABET for b in _ALPHABET]
    strings += [a + b + c for a in _ALPHABET for b in _ALPHABET for c in _ALPHABET]
    return sorted(strings, key=spelling_key)


def test_spelling_index_of_empty_is_zero() -> None:
    assert spelling_index("") == 0


def test_index_and_successor_step_by_one() -> None:
    """``spelling_index(successor(s)) == spelling_index(s) + 1`` for every spelling."""
    for s in _universe_of_strings():
        assert spelling_index(successor(s)) == spelling_index(s) + 1


def test_all_maximal_string_rolls_to_a_longer_zero_string() -> None:
    top = "\U0010ffff"
    assert successor(top) == "\x00\x00"
    assert successor(top + top) == "\x00\x00\x00"


@given(s=text(min_size=0, max_size=4))
def test_spelling_from_index_inverts_spelling_index(s: str) -> None:
    assert spelling_from_index(spelling_index(s)) == s


def test_spelling_index_is_strictly_monotone_in_shortlex() -> None:
    ordered = _universe_of_strings()
    indices = [spelling_index(s) for s in ordered]
    assert indices == sorted(indices)
    assert len(set(indices)) == len(indices)


def _interval_set(members: set[str]) -> IntervalSet:
    """Build an ``IntervalSet`` as the union of singletons -- the brute-force bridge."""
    result = IntervalSet.empty()
    for m in members:
        result = result.union(IntervalSet.point(m))
    return result


@given(members=lists(_SMALL, max_size=8))
def test_contains_and_cardinality_match_a_python_set(members: list[str]) -> None:
    as_set = set(members)
    ivs = _interval_set(as_set)
    for s in _universe_of_strings():
        assert ivs.contains(s) == (s in as_set)
    assert ivs.cardinality() == len(as_set)


@given(left=lists(_SMALL, max_size=6), right=lists(_SMALL, max_size=6))
def test_set_operations_match_python(left: list[str], right: list[str]) -> None:
    a, b = set(left), set(right)
    ivs_a, ivs_b = _interval_set(a), _interval_set(b)
    universe = _universe_of_strings()

    union = ivs_a.union(ivs_b)
    difference = ivs_a.difference(ivs_b)
    for s in universe:
        assert union.contains(s) == (s in a or s in b)
        assert difference.contains(s) == (s in a and s not in b)
    assert ivs_a.intersects(ivs_b) == bool(a & b)


@given(members=lists(_SMALL, min_size=1, max_size=8))
def test_rank_and_nth_round_trip_in_spelling_order(members: list[str]) -> None:
    ivs = _interval_set(set(members))
    ordered = sorted(set(members), key=spelling_key)
    for i, s in enumerate(ordered):
        assert ivs.rank(s) == i
        assert ivs.nth(i) == s


def test_final_segment_is_infinite() -> None:
    tail = IntervalSet.from_range("a", None)
    assert tail.cardinality() is None
    assert tail.contains("a")
    assert tail.contains("zzzz")
    assert not tail.contains("\x00")  # below "a" in shortlex


def test_bounded_range_iterates_in_spelling_order() -> None:
    ivs = IntervalSet.from_range("a", successor("e"))
    assert list(ivs) == ["a", "b", "c", "d", "e"]


def test_reversed_range_is_empty() -> None:
    assert IntervalSet.from_range("e", "a").is_empty()
