"""Tests for core.order: the shortlex spelling order and symbolic windows.

`spelling_key`/`successor` must realize one well-order of type omega, and
`Window` must agree with brute-force filtering over a tiny alphabet where
every operation can be checked exhaustively.
"""

from __future__ import annotations

from hypothesis import given
from hypothesis.strategies import text

from hejmark.core.floor.order import Window, spelling_key, successor

# A tiny alphabet whose short strings can be enumerated and checked exhaustively.
_ALPHABET = "abc"


def _universe_of_strings() -> list[str]:
    """Every string of length <= 3 over the tiny alphabet, in shortlex order."""
    strings = ["", *_ALPHABET]
    strings += [a + b for a in _ALPHABET for b in _ALPHABET]
    strings += [a + b + c for a in _ALPHABET for b in _ALPHABET for c in _ALPHABET]
    return sorted(strings, key=spelling_key)


def test_shortlex_sorts_shorter_first_then_by_code_point() -> None:
    assert sorted(["ba", "b", "a", "", "ab"], key=spelling_key) == ["", "a", "b", "ab", "ba"]


@given(s=text(max_size=4))
def test_successor_is_strictly_next(s: str) -> None:
    """The successor sorts strictly after ``s``, with nothing in between."""
    nxt = successor(s)
    assert spelling_key(s) < spelling_key(nxt)


def test_successor_steps_within_a_length_then_rolls_over() -> None:
    assert successor("") == "\x00"
    assert successor("a") == "b"
    assert successor("az") == "a{"
    assert successor("ab\U0010ffff") == "ac\x00"


def test_all_maximal_string_rolls_to_a_longer_zero_string() -> None:
    top = "\U0010ffff"
    assert successor(top) == "\x00\x00"
    assert successor(top + top) == "\x00\x00\x00"


def test_bounded_window_iterates_in_spelling_order() -> None:
    window = Window("a", successor("e"))
    assert list(window) == ["a", "b", "c", "d", "e"]


def test_window_contains_matches_brute_force() -> None:
    window = Window("b", "bb")
    for s in _universe_of_strings():
        assert window.contains(s) == (spelling_key("b") <= spelling_key(s) < spelling_key("bb"))


def test_reversed_window_is_empty() -> None:
    window = Window("e", "a")
    assert not window.contains("e")
    assert list(window) == []
