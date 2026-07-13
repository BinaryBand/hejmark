"""Tests for denotation: the constructor algebra in :mod:`Himark.core.universe`.

These verify that :func:`Himark.parse` and :func:`Himark.core.universe.denote`
correctly apply union, subtraction, fold flattening, and range expansion to
produce flat, valued universes.
"""

from __future__ import annotations

from Himark import Entry, match, parse

# ---------------------------------------------------------------------------
# Smoke denotations (Stage 3 acceptance)
# ---------------------------------------------------------------------------


def test_fold_flatten_merges_faces() -> None:
    """``{a,{a,A}}`` -> one universe, entries ``[("a",), ("A",)]``."""
    result = parse("{a,{a,A}}")
    assert len(result.universes) == 1
    entries = result.universes[0].entries
    assert entries == (
        Entry(("a",), 0),
        Entry(("A",), 1),
    )


def test_deep_fold_flattens_fully() -> None:
    """``{a,{b,{c,d},e,{f,g}}}`` -> entries ``[("a",), ("b","c","d","e","f","g")]``."""
    result = parse("{a,{b,{c,d},e,{f,g}}}")
    entries = result.universes[0].entries
    assert len(entries) == 2
    assert entries[0] == Entry(("a",), 0)
    assert entries[1] == Entry(("b", "c", "d", "e", "f", "g"), 1)


def test_subtraction_of_only_entry_makes_empty() -> None:
    """``{a,!{a}}`` -> zero entries."""
    result = parse("{a,!{a}}")
    assert len(result.universes[0].entries) == 0


def test_stage3_match_smoke_by_value() -> None:
    """``match("{a,b}{x,y}", "zzby")`` -> span ``(2, 4)``, value ``3``."""
    result = match("{a,b}{x,y}", "zzby")
    assert result is not None
    assert result.span == (2, 4)
    assert result.value == 3


def test_stage3_match_backtracking_ab() -> None:
    """On ``"ab"``, ``{a,ab}{b,c}`` spells ``a`` then ``b`` (backtrack)."""
    result = match("{a,ab}{b,c}", "ab")
    assert result is not None
    assert tuple(p.face for p in result.parts) == ("a", "b")


def test_stage3_match_greedy_abc() -> None:
    """On ``"abc"``, ``{a,ab}{b,c}`` spells ``ab`` then ``c`` (greedy)."""
    result = match("{a,ab}{b,c}", "abc")
    assert result is not None
    assert tuple(p.face for p in result.parts) == ("ab", "c")


# ---------------------------------------------------------------------------
# Fold-flatten equivalence
# ---------------------------------------------------------------------------


def test_fold_flatten_equivalence() -> None:
    """``parse("{a,{b,{c,C}}}").universes == parse("{a,{b,c,C}}").universes``."""
    left = parse("{a,{b,{c,C}}}").universes
    right = parse("{a,{b,c,C}}").universes
    assert left == right


# ---------------------------------------------------------------------------
# Ranges
# ---------------------------------------------------------------------------


def test_range_five_entries() -> None:
    """``{a..e}`` has five entries (a, b, c, d, e)."""
    result = parse("{a..e}")
    entries = result.universes[0].entries
    assert len(entries) == 5
    faces = [e.faces[0] for e in entries]
    assert faces == ["a", "b", "c", "d", "e"]


def test_range_single_entry() -> None:
    """``{a..a}`` has one entry."""
    result = parse("{a..a}")
    assert len(result.universes[0].entries) == 1
    assert result.universes[0].entries[0].faces == ("a",)


def test_range_reversed_is_empty() -> None:
    """``{e..a}`` has zero entries (lo > hi)."""
    result = parse("{e..a}")
    assert len(result.universes[0].entries) == 0


# ---------------------------------------------------------------------------
# Subtraction
# ---------------------------------------------------------------------------


def test_subtraction_renumbers() -> None:
    """``{a,b,c,!{b}}`` gives ``a`` value 0 and ``c`` value 1."""
    result = parse("{a,b,c,!{b}}")
    entries = result.universes[0].entries
    assert len(entries) == 2
    assert entries[0] == Entry(("a",), 0)
    assert entries[1] == Entry(("c",), 1)


def test_reunion_after_subtraction() -> None:
    """``{a,!{a},a}`` has one entry (the second ``a`` re-claims)."""
    result = parse("{a,!{a},a}")
    entries = result.universes[0].entries
    assert len(entries) == 1
    assert entries[0] == Entry(("a",), 0)


def test_any_face_subtraction() -> None:
    """``{{a,A},!{A}}`` is empty (subtraction matches by any face)."""
    result = parse("{{a,A},!{A}}")
    assert len(result.universes[0].entries) == 0


# ---------------------------------------------------------------------------
# Compression equivalence / positional value
# ---------------------------------------------------------------------------


def test_compression_equivalence_by_value() -> None:
    """``{a,b}{x,y}`` and ``{ax,ay,bx,by}`` give the same value for ``"by"``."""
    product_val = match("{a,b}{x,y}", "by")
    compressed_val = match("{ax,ay,bx,by}", "by")
    assert product_val is not None
    assert compressed_val is not None
    assert product_val.value == 3
    assert product_val.value == compressed_val.value


def test_positional_value_mixed_radix() -> None:
    """``{a,b,c}{a,b,c}`` on ``"cb"`` gives value 7."""
    result = match("{a,b,c}{a,b,c}", "cb")
    assert result is not None
    assert result.value == 7
