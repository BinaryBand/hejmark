"""Tests for app.engine: wiring the parser adapter to core denotation and matching.

The engine's own job is small -- combine `to_ast` with `denote`, and accept
either a denoted Query or raw source -- so that is what these exercise.
"""

from __future__ import annotations

from Himark.app.engine import finditer, match, parse
from Himark.core.universe import Entry, Query


def test_parse_denotes_source_to_a_query() -> None:
    query = parse("{a,b}")

    assert isinstance(query, Query)
    assert query.source == "{a,b}"
    assert query.universes[0].entries == (Entry(("a",), 0), Entry(("b",), 1))


def test_parse_keeps_universes_most_significant_first() -> None:
    query = parse("{a,b}{x,y}")

    assert len(query.universes) == 2
    assert query.universes[0].entries[0] == Entry(("a",), 0)
    assert query.universes[1].entries[0] == Entry(("x",), 0)


def test_match_accepts_raw_source() -> None:
    found = match("{a,b}", "zzb")

    assert found is not None
    assert found.span == (2, 3)


def test_match_accepts_a_denoted_query() -> None:
    query = parse("{a,b}")

    assert match(query, "zzb") == match("{a,b}", "zzb")


def test_match_start_offset_is_passed_through() -> None:
    found = match("{a,b}", "ab", start=1)

    assert found is not None
    assert found.span == (1, 2)


def test_finditer_accepts_both_source_and_query() -> None:
    from_source = [m.span for m in finditer("{a,b}", "ab")]
    from_query = [m.span for m in finditer(parse("{a,b}"), "ab")]

    assert from_source == from_query == [(0, 1), (1, 2)]
