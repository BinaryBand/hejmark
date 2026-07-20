"""Tests for core.match: leftmost-greedy membership matching.

These drive `match`/`finditer` on hand-built queries (AST nodes through
`denote`), so the parser is not in the loop. The matcher knows only spellings,
so every assertion is about spans and faces.
"""

from __future__ import annotations

from hejmark.core.floor.syntax import Face, Fold, UniverseNode
from hejmark.core.floor.universe import Query, Universe, denote
from hejmark.core.scan.match import finditer, match


def _universe(*faces: str) -> Universe:
    """Build a universe of single-faced entries in declaration order."""
    return denote(UniverseNode(tuple(Face(f) for f in faces)))


def _query(*universes: Universe) -> Query:
    return Query("<hand-built>", universes)


def test_leftmost_match_skips_unmatched_prefix() -> None:
    found = match(_query(_universe("a")), "xxa")

    assert found is not None
    assert found.span == (2, 3)
    assert found.parts[0].face == "a"


def test_no_match_returns_none() -> None:
    assert match(_query(_universe("a")), "zzz") is None


def test_start_offset_is_honoured() -> None:
    found = match(_query(_universe("a")), "aXa", start=1)

    assert found is not None
    assert found.span == (2, 3)


def test_longest_face_wins() -> None:
    """Candidates are tried longest-first regardless of declaration order."""
    found = match(_query(_universe("a", "ab")), "ab")

    assert found is not None
    assert found.span == (0, 2)
    assert found.parts[0].face == "ab"


def test_backtracks_when_the_greedy_choice_strands_the_rest() -> None:
    """`ab` is longest at position 0, but then `b` cannot match -- so back off to `a`."""
    found = match(_query(_universe("a", "ab"), _universe("b")), "ab")

    assert found is not None
    assert found.span == (0, 2)
    assert [part.face for part in found.parts] == ["a", "b"]


def test_empty_universe_in_a_product_matches_nothing() -> None:
    assert match(_query(_universe("a"), _universe()), "a") is None


def test_zero_width_is_never_accepted() -> None:
    """The unit universe wears only the empty spelling, so no match exists."""
    unit = denote(UniverseNode((Fold(UniverseNode(())),)))

    assert match(_query(unit), "anything") is None


def test_matching_is_membership_by_any_face() -> None:
    """A fold's alternate spelling hits like any other."""
    folded = denote(UniverseNode((Fold(UniverseNode((Face("cat"), Face("feline")))),)))
    found = match(_query(folded), "a feline")

    assert found is not None
    assert found.parts[0].face == "feline"


def test_finditer_yields_non_overlapping_matches() -> None:
    found = list(finditer(_query(_universe("aa")), "aaaa"))

    assert [m.span for m in found] == [(0, 2), (2, 4)]


def test_finditer_is_empty_when_nothing_matches() -> None:
    assert list(finditer(_query(_universe("a")), "zzz")) == []
