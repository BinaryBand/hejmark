"""The driver: source in through the compiler, matches or documents out."""

from __future__ import annotations

import pytest

from hejmark.adapters.parser import AntlrParser
from hejmark.core.driver import finditer, match, parse, run
from hejmark.core.engine.scan.match import Query, Slot
from hejmark.core.ir.errors import HimarkScopeError

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
    assert query.universe().contains("a")
    assert query.universe(2).contains("c")


def test_parse_refuses_anything_but_a_single_query() -> None:
    """The query-level API takes a query; a whole script goes through ``run``."""
    with pytest.raises(HimarkScopeError, match="single query expression"):
        parse(_to_ast, '{a} => "x"')
    with pytest.raises(HimarkScopeError, match="single query expression"):
        parse(_to_ast, "uni d = {a}")
    with pytest.raises(HimarkScopeError, match="single query expression"):
        parse(_to_ast, '{a} <=>[@spellings] "x"')


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


def test_a_back_referencing_unit_enters_the_query_late() -> None:
    """A unit reading a factor to its left cannot denote yet; it rides as a slot."""
    query = parse(_to_ast, "{a,b}{$1}")
    assert isinstance(query.universes[1], Slot)
    assert query.universes[1].needs == (1,)
    assert query.universe(0).contains("a")


def test_a_read_not_strictly_left_is_refused() -> None:
    """A read of the reading factor, one to its right, or past the query, binds nothing."""
    for source in ("{$1}", "{a}{$2}", "{a}{$3}"):
        with pytest.raises(HimarkScopeError, match="stand to its left"):
            parse(_to_ast, source)


def test_run_compiles_and_executes_a_script() -> None:
    """The whole pipeline: parse, compile to a program, execute against text."""
    assert run(_to_ast, '{a} => "x"', "abc") == "xbc"
