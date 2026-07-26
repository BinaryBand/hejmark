"""The driver: source in through the compiler, matches or documents out."""

from __future__ import annotations

import pytest

from hejmark.adapters.parser import AntlrParser
from hejmark.core.driver import compile_program, finditer, match, parse, run
from hejmark.core.engine.scan.match import Query, Slot
from hejmark.core.ir.errors import HimarkScopeError, HimarkSentinelError
from hejmark.core.ir.program import CompiledQuery, CompiledStatement, LateSlot

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
        parse(_to_ast, '{a} <=> "x"')


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


def test_run_refuses_a_document_that_arrives_spelling_a_sentinel() -> None:
    """The L2 ingest guard sits on the run path: a noncharacter document is refused."""
    with pytest.raises(HimarkSentinelError, match="noncharacter"):
        run(_to_ast, '{a} => "x"', "ab\ufdd0c")


def test_compile_program_stops_at_the_data() -> None:
    """The first half of `run`, kept as the payload a host in another process reads."""
    program = compile_program(_to_ast, '{a} => "x"')
    assert len(program.statements) == 1
    assert isinstance(program.statements[0], CompiledStatement)
    assert program.sentinels == ()


def test_compile_program_carries_a_back_reference_as_a_slot() -> None:
    """The format expresses a late slot; what it cannot express is the resolver.

    So a back-referencing script compiles to a program rather than being
    refused, and it is the *executing* engine that has to hold the resolver --
    which is why `compile_program` drops it rather than returning it.
    """
    program = compile_program(_to_ast, '{a,b}{$1} => "x"')
    statement = program.statements[0]
    assert isinstance(statement, CompiledStatement)
    step = statement.steps[0]
    assert isinstance(step, CompiledQuery)
    assert isinstance(step.factors[1], LateSlot)
