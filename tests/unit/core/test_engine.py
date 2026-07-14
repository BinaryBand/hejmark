"""Tests for core.engine: wiring a parser port to core denotation and matching.

The engine's own job is small -- combine `to_ast` with `denote`, and accept
either a denoted Query or raw source -- so that is what these exercise.
"""

from __future__ import annotations

from Himark.adapters.parser import to_ast
from Himark.core.engine import finditer, match, parse
from Himark.core.universe import Query


def test_parse_denotes_source_to_a_query() -> None:
    query = parse(to_ast, "{a,b}")

    assert isinstance(query, Query)
    assert query.source == "{a,b}"
    assert [e.faces for e in query.universes[0].entries()] == [("a",), ("b",)]


def test_parse_keeps_universes_most_significant_first() -> None:
    query = parse(to_ast, "{a,b}{x,y}")

    assert len(query.universes) == 2
    assert next(iter(query.universes[0].entries())).faces == ("a",)
    assert next(iter(query.universes[1].entries())).faces == ("x",)


def test_match_accepts_raw_source() -> None:
    found = match(to_ast, "{a,b}", "zzb")

    assert found is not None
    assert found.span == (2, 3)


def test_match_accepts_a_denoted_query() -> None:
    query = parse(to_ast, "{a,b}")

    assert match(to_ast, query, "zzb") == match(to_ast, "{a,b}", "zzb")


def test_match_start_offset_is_passed_through() -> None:
    found = match(to_ast, "{a,b}", "ab", start=1)

    assert found is not None
    assert found.span == (1, 2)


def test_finditer_accepts_both_source_and_query() -> None:
    from_source = [m.span for m in finditer(to_ast, "{a,b}", "ab")]
    from_query = [m.span for m in finditer(to_ast, parse(to_ast, "{a,b}"), "ab")]

    assert from_source == from_query == [(0, 1), (1, 2)]
