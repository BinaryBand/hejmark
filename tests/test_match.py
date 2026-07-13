"""Tests for the leftmost-greedy matcher with canonical-parse backtracking.

These verify :func:`Himark.match` and :func:`Himark.finditer` scanning behaviour,
face identification, value computation on both axes, and edge cases around empty
universes in products.
"""

from __future__ import annotations

from Himark import finditer, match

# ---------------------------------------------------------------------------
# Leftmost match
# ---------------------------------------------------------------------------


def test_leftmost_single_face_match() -> None:
    """``{b}`` on ``"abc"`` spans ``(1, 2)``."""
    result = match("{b}", "abc")
    assert result is not None
    assert result.span == (1, 2)
    assert result.parts[0].face == "b"


def test_greedy_prefers_longest_face() -> None:
    """``{a,ab}`` on ``"abc"`` matches ``"ab"`` (entry 1, i.e. the second entry)."""
    result = match("{a,ab}", "abc")
    assert result is not None
    assert result.parts[0].face == "ab"
    assert result.parts[0].entry.value == 1


# ---------------------------------------------------------------------------
# Backtracking (Stage 3 acceptance pair)
# ---------------------------------------------------------------------------


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


# ---------------------------------------------------------------------------
# Empty universe in product
# ---------------------------------------------------------------------------


def test_empty_universe_alone_matches_nothing() -> None:
    """An empty-entries universe alone matches nothing."""
    result = match("{a,!{a}}", "xyz")
    assert result is None


def test_empty_factor_in_product_matches_nothing() -> None:
    """``{x}{a,!{a}}`` matches nothing because the trailing factor is empty."""
    result = match("{x}{a,!{a}}", "xyz")
    assert result is None


# ---------------------------------------------------------------------------
# Face identification
# ---------------------------------------------------------------------------


def test_face_identification_by_alternate_spelling() -> None:
    """``{x,{b,B}}`` on ``"B"`` gives value 1, face_index 1."""
    result = match("{x,{b,B}}", "B")
    assert result is not None
    assert result.value == 1
    assert result.parts[0].face_index == 1
    assert result.parts[0].face == "B"


# ---------------------------------------------------------------------------
# Face-axis value
# ---------------------------------------------------------------------------


def test_face_axis_value() -> None:
    """``{a,{b,B}}{c}`` on ``"Bc"`` gives value 1, face_value 1."""
    result = match("{a,{b,B}}{c}", "Bc")
    assert result is not None
    assert result.value == 1
    assert result.face_value == 1


def test_face_axis_value_both_positions() -> None:
    """Face axis sums correctly across all product positions."""
    # {a,{b,B}}{c,{d,D}} on "B D" -- each position picks the second face
    result = match("{a,{b,B}}{c,{d,D}}", "BD")
    assert result is not None
    # value: entry 1 at each of 2 positions, base is 2, 2 at each position
    # entry axis: 1*2 + 1 = 3
    assert result.value == 3
    assert result.face_value == 3


# ---------------------------------------------------------------------------
# finditer non-overlapping
# ---------------------------------------------------------------------------


def test_finditer_non_overlapping() -> None:
    """``{a}{a}`` on ``"aaaa"`` gives spans ``(0, 2)`` and ``(2, 4)``."""
    results = list(finditer("{a}{a}", "aaaa"))
    assert len(results) == 2
    assert results[0].span == (0, 2)
    assert results[1].span == (2, 4)


def test_finditer_no_match() -> None:
    """finditer on a text with no matches yields nothing."""
    results = list(finditer("{z}", "abc"))
    assert len(results) == 0


def test_finditer_resumes_past_match() -> None:
    """finditer does not overlap: ``{a}`` on ``"aaa"`` yields three single-char matches."""
    results = list(finditer("{a}", "aaa"))
    assert len(results) == 3
    assert [r.span for r in results] == [(0, 1), (1, 2), (2, 3)]
