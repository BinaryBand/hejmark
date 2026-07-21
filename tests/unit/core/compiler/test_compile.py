"""Compilation: a resolved script lowers to the boundary's pure-data Program."""

from __future__ import annotations

import pytest

from hejmark.adapters.parser import AntlrParser
from hejmark.core.compiler.compile import compile_script, lower, script
from hejmark.core.floor.syntax import Face, UniverseNode
from hejmark.core.floor.universe import denote
from hejmark.core.ir.errors import HimarkScopeError
from hejmark.core.ir.program import (
    CapturePart,
    CompiledIter,
    CompiledQuery,
    CompiledStatement,
    CompiledTemplate,
    LateResolver,
    LateSlot,
    Program,
    SentinelPart,
    TextPart,
    noncharacter,
)

_to_ast = AntlrParser().to_ast


def _compile(source: str) -> tuple[Program, LateResolver]:
    """Parse, resolve and lower a whole script."""
    node, env = script(_to_ast, source)
    return compile_script(node, env)


def test_script_resolves_declarations_over_the_std() -> None:
    """A script's own names sit alongside the seeded ones."""
    node, env = script(_to_ast, "uni mine = {a}")
    assert len(node.lines) == 1
    assert "mine" in env.unis
    assert "spellings" in env.unis


def test_a_statement_lowers_to_queries_and_templates() -> None:
    """Each step crosses as data: expanded factors, and templates part by part."""
    program, _ = _compile('sentinel s\n{a} => "x{{$1}}{{@s}}"')
    line = program.statements[0]
    assert isinstance(line, CompiledStatement)
    query, template = line.steps
    assert isinstance(query, CompiledQuery)
    assert query.factors == (UniverseNode((Face("a"),)),)
    assert isinstance(template, CompiledTemplate)
    assert template.parts == (TextPart("x"), CapturePart("$1"), SentinelPart("s"))


def test_a_back_reference_lowers_to_a_slot_and_its_resolver_answers() -> None:
    """The unit never crosses; a slot does, and the resolver expands it on demand."""
    program, resolver = _compile('{a,b}{$1} => "-"')
    line = program.statements[0]
    assert isinstance(line, CompiledStatement)
    query = line.steps[0]
    assert isinstance(query, CompiledQuery)
    assert query.factors[1] == LateSlot(0, (1,), 1)
    assert denote(resolver(0, ("a",))).contains("a")


def test_a_contract_expands_its_measure_at_compile_time() -> None:
    """The measure crosses as a floor node; only its name survives for diagnostics."""
    program, _ = _compile('{ba} <=>[@spellings] "ab"')
    line = program.statements[0]
    assert isinstance(line, CompiledIter)
    assert line.measure_name == "spellings"
    assert isinstance(line.measure, UniverseNode)


def test_an_unknown_measure_is_refused_at_compile_time() -> None:
    """A measure naming nothing is a compile error, not a first-pass surprise."""
    with pytest.raises(HimarkScopeError, match="unknown name"):
        _compile('{a} <=>[@nope] "b"')


def test_the_sentinel_table_rides_the_program() -> None:
    """Allocations cross as name-face pairs, in declaration order."""
    program, _ = _compile("sentinel s\nsentinel t")
    assert [sentinel.name for sentinel in program.sentinels] == ["s", "t"]
    assert all(noncharacter(sentinel.face) for sentinel in program.sentinels)


def test_lower_expands_each_factor_to_its_pre_denotation_ast() -> None:
    """The lowered form denotes to the same universes ``parse`` would build."""
    forms = lower(_to_ast, "{a,b}{c}")
    assert len(forms) == 2
    assert all(isinstance(form, UniverseNode) for form in forms)
    # {a,b} carries both faces, in order.
    assert forms[0].members == (Face("a"), Face("b"))
    assert denote(forms[1]).contains("c")


def test_lower_refuses_a_back_referencing_factor() -> None:
    """A slotted factor denotes only under a binding, so it cannot be lowered."""
    with pytest.raises(HimarkScopeError, match="back-referencing"):
        lower(_to_ast, "{a,b}{$1}")


def test_lower_refuses_anything_but_a_single_query() -> None:
    with pytest.raises(HimarkScopeError, match="single query expression"):
        lower(_to_ast, "uni d = {a}")
