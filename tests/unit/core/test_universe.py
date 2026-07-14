"""Tests for core.universe: denoting a faithful AST to flat, valued universes.

These drive `denote` on hand-built AST nodes, so the parser is not in the loop.
"""

from __future__ import annotations

from Himark.core.order import IntervalSet
from Himark.core.syntax import Face, Fold, Range, Subtract, UniverseNode
from Himark.core.universe import Entry, denote

# A materialized face piece is always a one-point interval set.
_P = IntervalSet.point


def test_union_is_ordered_and_deduplicates() -> None:
    universe = denote(UniverseNode((Face("a"), Face("b"), Face("a"))))

    assert universe.entries == (Entry((_P("a"),), 0), Entry((_P("b"),), 1))


def test_range_expands_inclusively() -> None:
    universe = denote(UniverseNode((Range("a", "e"),)))

    assert [entry.faces[0] for entry in universe.entries] == [_P(c) for c in "abcde"]
    assert [entry.value for entry in universe.entries] == [0, 1, 2, 3, 4]


def test_reversed_range_is_empty() -> None:
    assert denote(UniverseNode((Range("e", "a"),))).entries == ()


def test_fold_collapses_a_nested_universe_into_one_entry() -> None:
    inner = UniverseNode((Face("x"), Face("y")))
    universe = denote(UniverseNode((Face("a"), Fold(inner))))

    assert universe.entries == (Entry((_P("a"),), 0), Entry((_P("x"), _P("y")), 1))


def test_fold_drops_faces_already_claimed() -> None:
    """A fold only keeps faces no live entry has claimed -- union no-ops win."""
    inner = UniverseNode((Face("a"), Face("x")))
    universe = denote(UniverseNode((Face("a"), Fold(inner))))

    assert universe.entries == (Entry((_P("a"),), 0), Entry((_P("x"),), 1))


def test_subtraction_removes_entries_and_renumbers() -> None:
    """Values are assigned by final index, so subtraction renumbers what remains."""
    universe = denote(
        UniverseNode((Face("a"), Face("b"), Face("c"), Subtract(UniverseNode((Face("b"),)))))
    )

    assert universe.entries == (Entry((_P("a"),), 0), Entry((_P("c"),), 1))


def test_subtraction_removes_every_entry_sharing_a_face() -> None:
    """Naming any face of a folded entry removes the whole entry."""
    folded = UniverseNode((Face("x"), Face("y")))
    universe = denote(UniverseNode((Face("a"), Fold(folded), Subtract(UniverseNode((Face("y"),))))))

    assert universe.entries == (Entry((_P("a"),), 0),)


def test_face_can_be_reclaimed_after_subtraction() -> None:
    """Subtraction releases the claim, so a later union may re-add the spelling."""
    universe = denote(UniverseNode((Face("a"), Subtract(UniverseNode((Face("a"),))), Face("a"))))

    assert universe.entries == (Entry((_P("a"),), 0),)
