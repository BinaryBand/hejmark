"""Engine wiring: source in, denoted query or spliced document out."""

from __future__ import annotations

import pytest

from hejmark.adapters.parser import AntlrParser
from hejmark.core.engine import finditer, match, parse, script
from hejmark.core.floor.universe import Query
from hejmark.core.surface.ast import HimarkScopeError

_to_ast = AntlrParser().to_ast


def test_parse_denotes_source_to_a_query() -> None:
    """The source rides along on the query, which is what diagnostics quote."""
    query = parse(_to_ast, "{a,b}")
    assert isinstance(query, Query)
    assert query.source == "{a,b}"


def test_universes_stay_most_significant_first() -> None:
    """Adjacency is the product, and the leftmost factor moves slowest."""
    query = parse(_to_ast, "{a}{b}{c}")
    assert len(query.universes) == 3
    assert query.universes[0].contains("a")
    assert query.universes[2].contains("c")


def test_script_resolves_declarations_over_the_std() -> None:
    """A script's own names sit alongside the seeded ones."""
    node, env = script(_to_ast, "uni mine = {a}")
    assert len(node.lines) == 1
    assert "mine" in env.unis
    assert "spellings" in env.unis


def test_parse_refuses_anything_but_a_single_query() -> None:
    """The query-level API takes a query; a whole script goes through ``run``."""
    with pytest.raises(HimarkScopeError, match="single query expression"):
        parse(_to_ast, '{a} => "x"')
    with pytest.raises(HimarkScopeError, match="single query expression"):
        parse(_to_ast, "uni d = {a}")


def test_match_and_finditer_accept_source_or_a_denoted_query() -> None:
    """Denoting once and scanning many times is the same as scanning source."""
    query = parse(_to_ast, "{a}")
    assert match(_to_ast, query, "banana") == match(_to_ast, "{a}", "banana")
    assert len(list(finditer(_to_ast, query, "banana"))) == 3


def test_match_honours_the_start_offset() -> None:
    """Scanning resumes where the caller says, not always at zero."""
    found = match(_to_ast, "{a}", "banana", 2)
    assert found is not None
    assert found.span[0] == 3
