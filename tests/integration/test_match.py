"""Tests for the leftmost-greedy matcher, end to end through the parser.

These verify :func:`hejmark.match` and :func:`hejmark.finditer` scanning
behaviour: leftmost position, maximal munch, backtracking to the canonical
parse, matching by any face, and the closure scope (guarded bodies match;
unsettled ones raise instead of guessing).
"""

from __future__ import annotations

import pytest

from hejmark import finditer, match
from hejmark.core.universe import HimarkUnsettledError


def test_leftmost_single_face_match() -> None:
    """``{b}`` on ``"abc"`` spans ``(1, 2)``."""
    result = match("{b}", "abc")
    assert result is not None
    assert result.span == (1, 2)
    assert result.parts[0].face == "b"


def test_greedy_prefers_longest_face() -> None:
    """``{a,ab}`` on ``"abc"`` matches ``"ab"`` -- declaration order never selects."""
    result = match("{a,ab}", "abc")
    assert result is not None
    assert result.parts[0].face == "ab"


def test_backtracking_ab() -> None:
    """On ``"ab"``, ``{a,ab}{b,c}`` spells ``a`` then ``b``."""
    result = match("{a,ab}{b,c}", "ab")
    assert result is not None
    assert tuple(p.face for p in result.parts) == ("a", "b")


def test_greedy_abc() -> None:
    """On ``"abc"``, ``{a,ab}{b,c}`` spells ``ab`` then ``c``."""
    result = match("{a,ab}{b,c}", "abc")
    assert result is not None
    assert tuple(p.face for p in result.parts) == ("ab", "c")


def test_empty_universe_alone_matches_nothing() -> None:
    """Emptiness is meaningless, not invalid: the query runs and finds nothing."""
    assert match("{a,!{a}}", "xyz") is None


def test_empty_factor_in_product_matches_nothing() -> None:
    """``{x}{a,!{a}}`` matches nothing because the trailing factor is empty."""
    assert match("{x}{a,!{a}}", "xyz") is None


def test_matching_is_by_any_face() -> None:
    """``{x,{b,B}}`` on ``"B"`` hits the fold through its alternate spelling."""
    result = match("{x,{b,B}}", "B")
    assert result is not None
    assert result.parts[0].face == "B"


def test_stripped_face_no_longer_matches() -> None:
    """``{{cat,feline},!{feline}}`` keeps the entry but not the spelling."""
    assert match("{{cat,feline},!{feline}}", "a feline") is None
    result = match("{{cat,feline},!{feline}}", "the cat")
    assert result is not None
    assert result.parts[0].face == "cat"


def test_guarded_closure_matches_arbitrarily_deep() -> None:
    """``{ab,{a}&{b}}`` tiles a^n b^n -- beyond any regular face set."""
    result = match("{ab,{a}&{b}}", "xx" + "a" * 6 + "b" * 6 + "yy")
    assert result is not None
    assert result.span == (2, 14)


def test_unsettled_closure_is_out_of_matching_scope() -> None:
    """An unguarded body still denotes, but the matcher cannot decide absence."""
    with pytest.raises(HimarkUnsettledError):
        match("{a,{{{},0}}&}", "zzz")


def test_finditer_non_overlapping() -> None:
    """``{a}{a}`` on ``"aaaa"`` gives spans ``(0, 2)`` and ``(2, 4)``."""
    assert [r.span for r in finditer("{a}{a}", "aaaa")] == [(0, 2), (2, 4)]


def test_finditer_no_match() -> None:
    """finditer on a text with no matches yields nothing."""
    assert list(finditer("{z}", "abc")) == []


def test_finditer_resumes_past_match() -> None:
    """finditer does not overlap: ``{a}`` on ``"aaa"`` yields three matches."""
    assert [r.span for r in finditer("{a}", "aaa")] == [(0, 1), (1, 2), (2, 3)]
