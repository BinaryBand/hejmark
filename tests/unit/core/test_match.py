"""Tests for core.match: leftmost-greedy matching with canonical-parse backtracking.

These drive `match`/`finditer` on hand-built queries, so neither the parser nor
denotation is in the loop.
"""

from __future__ import annotations

from Himark.core.match import finditer, match
from Himark.core.universe import Entry, Query, Universe


def _universe(*entries: tuple[str, ...]) -> Universe:
    """Build a universe from face tuples; values follow declaration order."""
    return Universe(tuple(Entry(faces, i) for i, faces in enumerate(entries)))


def _query(*universes: Universe) -> Query:
    return Query("<hand-built>", universes)


def test_leftmost_match_skips_unmatched_prefix() -> None:
    found = match(_query(_universe(("a",))), "xxa")

    assert found is not None
    assert found.span == (2, 3)
    assert found.parts[0].face == "a"


def test_no_match_returns_none() -> None:
    assert match(_query(_universe(("a",))), "zzz") is None


def test_start_offset_is_honoured() -> None:
    found = match(_query(_universe(("a",))), "aXa", start=1)

    assert found is not None
    assert found.span == (2, 3)


def test_longest_face_wins() -> None:
    """Candidates are tried longest-first regardless of declaration order."""
    found = match(_query(_universe(("a",), ("ab",))), "ab")

    assert found is not None
    assert found.span == (0, 2)
    assert found.parts[0].face == "ab"


def test_backtracks_when_the_greedy_choice_strands_the_rest() -> None:
    """`ab` is longest at position 0, but then `b` cannot match -- so back off to `a`."""
    found = match(_query(_universe(("a",), ("ab",)), _universe(("b",))), "ab")

    assert found is not None
    assert found.span == (0, 2)
    assert [part.face for part in found.parts] == ["a", "b"]


def test_empty_universe_in_a_product_matches_nothing() -> None:
    assert match(_query(_universe(("a",)), _universe()), "a") is None


def test_value_folds_the_product_as_mixed_radix() -> None:
    """value = entry index of each position, folded most-significant-first."""
    query = _query(_universe(("a",), ("b",), ("c",)), _universe(("x",), ("y",)))
    found = match(query, "cy")

    assert found is not None
    # c is entry 2 of 3, y is entry 1 of 2 -> 2 * 2 + 1
    assert found.value == 5


def test_face_value_folds_the_chosen_spellings() -> None:
    """face_value indexes which spelling of each entry matched, same mixed radix."""
    found = match(_query(_universe(("a", "A")), _universe(("b", "B"))), "aB")

    assert found is not None
    assert found.value == 0
    # a is spelling 0 of 2, B is spelling 1 of 2 -> 0 * 2 + 1
    assert found.face_value == 1
    assert [part.face_index for part in found.parts] == [0, 1]


def test_finditer_yields_non_overlapping_matches() -> None:
    found = list(finditer(_query(_universe(("aa",))), "aaaa"))

    assert [m.span for m in found] == [(0, 2), (2, 4)]


def test_finditer_is_empty_when_nothing_matches() -> None:
    assert list(finditer(_query(_universe(("a",))), "zzz")) == []
