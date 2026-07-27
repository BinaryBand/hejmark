"""The driver: source in through the compiler, matches or documents out."""

from __future__ import annotations

from collections.abc import Iterator

import pytest

from hejmark.adapters.parser import AntlrParser
from hejmark.core.driver import Adapters, compile_program, finditer, match, parse, run
from hejmark.core.engine.scan.match import Query, Slot
from hejmark.core.engine.service import InProcess
from hejmark.core.floor.syntax import UniverseNode
from hejmark.core.ir.errors import HimarkScopeError, HimarkSentinelError
from hejmark.core.ir.program import (
    CompiledQuery,
    CompiledStatement,
    LateResolver,
    LateSlot,
    Program,
)

_adapters = Adapters(AntlrParser().to_ast, InProcess())


def test_parse_denotes_source_to_a_query() -> None:
    """The source rides along on the query, which is what diagnostics quote."""
    query = parse(_adapters, "{a,b}")
    assert isinstance(query, Query)
    assert query.source == "{a,b}"


def test_universes_stay_most_significant_first() -> None:
    """Adjacency is the product, and the leftmost factor moves slowest."""
    query = parse(_adapters, "{a}{b}{c}")
    assert len(query.universes) == 3
    assert query.universe().contains("a")
    assert query.universe(2).contains("c")


def test_parse_refuses_anything_but_a_single_query() -> None:
    """The query-level API takes a query; a whole script goes through ``run``."""
    with pytest.raises(HimarkScopeError, match="single query expression"):
        parse(_adapters, '{a} => "x"')
    with pytest.raises(HimarkScopeError, match="single query expression"):
        parse(_adapters, "uni d = {a}")
    with pytest.raises(HimarkScopeError, match="single query expression"):
        parse(_adapters, '{a} <=> "x"')


def test_match_and_finditer_accept_source_or_a_denoted_query() -> None:
    """Denoting once and scanning many times is the same as scanning source."""
    query = parse(_adapters, "{a}")
    assert match(_adapters, query, "banana") == match(_adapters, "{a}", "banana")
    assert len(list(finditer(_adapters, query, "banana"))) == 3


def test_match_honours_the_start_offset() -> None:
    """Scanning resumes where the caller says, not always at zero."""
    found = match(_adapters, "{a}", "banana", 2)
    assert found is not None
    assert found.span[0] == 3


def test_a_back_referencing_unit_enters_the_query_late() -> None:
    """A unit reading a factor to its left cannot denote yet; it rides as a slot."""
    query = parse(_adapters, "{a,b}{$1}")
    assert isinstance(query.universes[1], Slot)
    assert query.universes[1].needs == (1,)
    assert query.universe(0).contains("a")


def test_a_read_not_strictly_left_is_refused() -> None:
    """A read of the reading factor, one to its right, or past the query, binds nothing."""
    for source in ("{$1}", "{a}{$2}", "{a}{$3}"):
        with pytest.raises(HimarkScopeError, match="stand to its left"):
            parse(_adapters, source)


def test_run_compiles_and_executes_a_script() -> None:
    """The whole pipeline: parse, compile to a program, execute against text."""
    assert run(_adapters, '{a} => "x"', "abc") == "xbc"


def test_run_refuses_a_document_that_arrives_spelling_a_sentinel() -> None:
    """The L2 ingest guard sits on the run path: a noncharacter document is refused."""
    with pytest.raises(HimarkSentinelError, match="noncharacter"):
        run(_adapters, '{a} => "x"', "ab\ufdd0c")


def test_compile_program_stops_at_the_data() -> None:
    """The first half of `run`, kept as the payload a host in another process reads."""
    program = compile_program(_adapters, '{a} => "x"')
    assert len(program.statements) == 1
    assert isinstance(program.statements[0], CompiledStatement)
    assert program.sentinels == ()


def test_compile_program_carries_a_back_reference_as_a_slot() -> None:
    """The format expresses a late slot; what it cannot express is the resolver.

    So a back-referencing script compiles to a program rather than being
    refused, and it is the *executing* engine that has to hold the resolver --
    which is why `compile_program` drops it rather than returning it.
    """
    program = compile_program(_adapters, '{a,b}{$1} => "x"')
    statement = program.statements[0]
    assert isinstance(statement, CompiledStatement)
    step = statement.steps[0]
    assert isinstance(step, CompiledQuery)
    assert isinstance(step.factors[1], LateSlot)


class _Recording:
    """A stand-in engine the core has never heard of: satisfies the port, logs, delegates."""

    def __init__(self) -> None:
        self.verbs: list[str] = []
        self._real = InProcess()

    def run(self, program: Program, document: str, resolver: LateResolver) -> str:
        self.verbs.append("run")
        return self._real.run(program, document, resolver)

    def canonical_faces(self, node: UniverseNode) -> Iterator[str]:
        self.verbs.append("canonical_faces")
        return self._real.canonical_faces(node)


def test_an_engine_the_core_never_imports_can_be_substituted() -> None:
    """The property the port exists for: execution goes wherever the adapters say.

    Nothing under `core/` names `_Recording`, yet a whole run reaches it -- which
    is what an out-of-process engine will rely on.
    """
    engine = _Recording()

    assert run(Adapters(AntlrParser().to_ast, engine), '{a..z} => "X"', "hi there") == "XX XXXXX"
    assert engine.verbs == ["run"]


def test_expansion_reads_denotation_through_the_same_port() -> None:
    """`@0` and value cuts are defined by a denotation read, and it goes to the engine."""
    engine = _Recording()

    source = 'def z = {@0}\n{0..9}[z] => "X"'
    assert run(Adapters(AntlrParser().to_ast, engine), source, "a0b7") == "aXb7"

    assert "canonical_faces" in engine.verbs
