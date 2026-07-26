"""Compilation: a resolved script lowers to the boundary's pure-data Program."""

from __future__ import annotations

import pytest

from hejmark.adapters.library import standard_library
from hejmark.adapters.parser import AntlrParser
from hejmark.core.compiler.compile import (
    Fragment,
    compile_script,
    lower,
    lower_fragments,
    script,
)
from hejmark.core.floor.syntax import Face, UniverseNode
from hejmark.core.floor.universe import denote
from hejmark.core.ir.errors import HimarkScopeError
from hejmark.core.ir.program import (
    SENTINEL_BASE,
    CapturePart,
    CompiledQuery,
    CompiledStatement,
    CompiledTemplate,
    EagerFactor,
    LateResolver,
    LateSlot,
    Program,
    SentinelPart,
    TextPart,
)

_to_ast = AntlrParser().to_ast


def _compile(source: str) -> tuple[Program, LateResolver]:
    """Parse, resolve and lower a whole script."""
    node, env = script(_to_ast, source)
    return compile_script(node, env)


def test_script_resolves_declarations_over_the_std() -> None:
    """A script's own names sit alongside the std's, when the prelude is supplied."""
    node, env = script(_to_ast, "uni mine = {a}", standard_library())
    assert len(node.lines) == 1
    assert "mine" in env.unis
    assert "str" in env.unis


def test_a_statement_lowers_to_queries_and_templates() -> None:
    """Each step crosses as data: expanded factors, and templates part by part."""
    program, _ = _compile('sentinel s\n{a} => "x{{$1}}{{@s}}"')
    line = program.statements[0]
    assert isinstance(line, CompiledStatement)
    query, template = line.steps
    assert isinstance(query, CompiledQuery)
    assert query.factors == (EagerFactor(UniverseNode((Face("a"),))),)
    assert isinstance(template, CompiledTemplate)
    assert template.parts == (TextPart("x"), CapturePart("$1"), SentinelPart("s"))


def test_a_back_reference_lowers_to_a_slot_and_its_resolver_answers() -> None:
    """The unit never crosses; a slot does, and the resolver expands it on demand."""
    program, resolver = _compile('{a,b}{$1} => "-"')
    line = program.statements[0]
    assert isinstance(line, CompiledStatement)
    query = line.steps[0]
    assert isinstance(query, CompiledQuery)
    assert query.factors[1] == LateSlot(0, (1,))
    assert denote(resolver(0, ("a",))).contains("a")


def test_the_sentinel_table_rides_the_program() -> None:
    """Allocations cross as name-face pairs, in declaration order."""
    program, _ = _compile("sentinel s\nsentinel t")
    assert [sentinel.name for sentinel in program.sentinels] == ["s", "t"]
    assert all(ord(sentinel.face) >= SENTINEL_BASE for sentinel in program.sentinels)


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


def test_fragments_share_the_names_any_of_them_declares() -> None:
    """A name declared in one fragment is in scope in the next, as in one file."""
    lowered = lower_fragments(_to_ast, ["uni d = {a,b}", "@d{c}"])
    assert lowered[0] == Fragment()  # declarations alone: names, not a query
    forms = lowered[1].forms
    assert forms is not None
    assert forms[0].members == (Face("a"), Face("b"))
    assert denote(forms[1]).contains("c")


def test_fragments_read_a_name_declared_after_the_fragment_using_it() -> None:
    """Collection is over every fragment's lines, so scope is the set, not a prefix."""
    lowered = lower_fragments(_to_ast, ["@d", "uni d = {a}"])
    forms = lowered[0].forms
    assert forms is not None
    assert denote(forms[0]).contains("a")
    assert lowered[1] == Fragment()


def test_a_broken_fragment_carries_its_message_and_the_others_still_lower() -> None:
    """One fragment mid-keystroke is not a reason for the rest to stop answering."""
    lowered = lower_fragments(_to_ast, ["{a", "{b}", "@nope"])
    assert lowered[0].error is not None
    assert lowered[1].forms == (UniverseNode((Face("b"),)),)
    assert lowered[2].error is not None
    assert "nope" in lowered[2].error


def test_fragments_refuse_a_name_two_of_them_declare() -> None:
    """Two fragments are two lines of one script, so the collision is the script's."""
    with pytest.raises(HimarkScopeError, match="duplicate name"):
        lower_fragments(_to_ast, ["uni d = {a}", "uni d = {b}"])


def test_fragments_refuse_a_cycle_that_spans_two_of_them() -> None:
    """Acyclicity is checked over the joined text, which is where the cycle is."""
    with pytest.raises(HimarkScopeError):
        lower_fragments(_to_ast, ["uni a = @b", "uni b = @a"])


def test_a_fragment_holding_two_queries_is_still_refused() -> None:
    """Sharing an environment does not make a fragment a script of its own."""
    error = lower_fragments(_to_ast, ["{a}\n{b}"])[0].error
    assert error is not None
    assert "single query expression" in error
