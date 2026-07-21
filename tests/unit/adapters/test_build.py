"""The tree walker transcribes the grammar faithfully, resolving nothing."""

from __future__ import annotations

import pytest

from hejmark.adapters.parser import AntlrParser
from hejmark.core.compiler.ast import (
    DefDecl,
    Expr,
    Interp,
    IterStatement,
    Operand,
    Ref,
    RefInterp,
    Segments,
    SentinelDecl,
    Statement,
    Template,
    Text,
    UniDecl,
    Unit,
    UniverseNode,
)
from hejmark.core.floor.syntax import Closure, Face, Final, HimarkSyntaxError, Range

_to_ast = AntlrParser().to_ast


def _line(source: str) -> object:
    """The single line a one-line script holds."""
    return _to_ast(source).lines[0]


def _members(source: str) -> tuple[object, ...]:
    """The members of the single universe a one-line query holds."""
    line = _line(source)
    assert isinstance(line, Statement)
    step = line.steps[0]
    assert isinstance(step, Expr)
    base = step.units[0].base
    assert isinstance(base, UniverseNode)
    return base.members


def test_a_range_and_a_final_segment_are_distinct_members() -> None:
    """`{a..z}` is bounded and `{a..}` is not; the grammar labels them apart."""
    assert _members("{a..z}") == (Range("a", "z"),)
    assert _members("{a..}") == (Final("a"),)


def test_a_face_is_assembled_from_its_character_tokens() -> None:
    """A face lexes one character at a time, so the walker joins them."""
    assert _members("{cat}") == (Segments((Face("cat"),)),)


def test_escapes_resolve_to_their_characters() -> None:
    """Structural characters are spellable, and the escape is gone by the AST."""
    assert _members(r"{\{}") == (Segments((Face("{"),)),)
    assert _members(r"{a\&b}") == (Segments((Face("a&b"),)),)


def test_a_bare_closure_token_is_its_own_segment() -> None:
    """`&` is the self-reference, not a face."""
    assert _members("{&}") == (Segments((Closure(),)),)


def test_nothing_is_classified_at_build_time() -> None:
    """`@shorter w` is an application and `{a}{b}` a product; only binding knows."""
    segments = _members("{@shorter w}")[0]
    assert isinstance(segments, Segments)
    assert isinstance(segments.segments[0], Unit)
    assert segments.segments[1] == Face("w")


def test_a_uni_declaration_carries_its_name_and_expression() -> None:
    """`uni name = expr` is a declaration, not a statement."""
    line = _line("uni d = {0..9}")
    assert isinstance(line, UniDecl)
    assert line.name == "d"


def test_a_sentinel_declaration_carries_only_its_name() -> None:
    """`sentinel name` has no body: the resolver allocates the face."""
    assert _line("sentinel start") == SentinelDecl("start")


def test_a_sentinel_read_is_its_own_template_part() -> None:
    """`{{@name}}` reads the environment where `{{$}}` reads the hit."""
    line = _line('{a} => "{{@start}}{{$}}"')
    assert isinstance(line, Statement)
    template = line.steps[1]
    assert isinstance(template, Template)
    assert template.parts == (RefInterp("start"), Interp("$"))


def test_a_definition_carries_its_parameters() -> None:
    """A pair parameter is one parameter, written `lo..hi`."""
    line = _line("where lo..hi := {a}")
    assert isinstance(line, DefDecl)
    assert line.params[0].lo == "lo"
    assert line.params[0].hi == "hi"


def test_a_pipeline_stays_a_flat_item_list() -> None:
    """Stage names and arguments lex alike, so the walker keeps them flat."""
    line = _line("{0..9}[where 8..12 pad 1..2]")
    assert isinstance(line, Statement)
    step = line.steps[0]
    assert isinstance(step, Expr)
    items = step.units[0].pipeline
    assert [(item.lo, item.hi) for item in items] == [
        ("where", None),
        ("8", "12"),
        ("pad", None),
        ("1", "2"),
    ]


def test_a_braced_exponent_unwraps_to_its_parameter_name() -> None:
    """`fill^{w'}` names a parameter; the braces are syntax, not a universe."""
    line = _line("pad w..w' := {@fill^{w'} _}")
    assert isinstance(line, DefDecl)
    segments = line.expr.units[0].base
    assert isinstance(segments, UniverseNode)
    member = segments.members[0]
    assert isinstance(member, Segments)
    first = member.segments[0]
    assert isinstance(first, Unit)
    assert first.exponent == "w'"
    assert member.segments[1] == Unit(Operand())


def test_a_statement_chains_its_steps() -> None:
    """Steps are joined by `=>`, each a query or a template."""
    line = _line('{a} => "x" => {b}')
    assert isinstance(line, Statement)
    assert [type(step).__name__ for step in line.steps] == ["Expr", "Template", "Expr"]


def test_a_template_separates_text_from_interpolation() -> None:
    """Literal text lands as written; each site holds one capture read."""
    line = _line('{a} => "<b>{{$0}}</b>"')
    assert isinstance(line, Statement)
    template = line.steps[1]
    assert isinstance(template, Template)
    assert template.parts == (Text("<b>"), Interp("$0"), Text("</b>"))


def test_a_reference_drops_its_sigil() -> None:
    """The sigil keeps a name from reading as a spelling; it is not part of the name."""
    line = _line("{@spellings}")
    assert isinstance(line, Statement)
    step = line.steps[0]
    assert isinstance(step, Expr)
    base = step.units[0].base
    assert isinstance(base, UniverseNode)
    member = base.members[0]
    assert isinstance(member, Segments)
    assert member.segments[0] == Unit(Ref("spellings"))


def test_a_syntax_error_is_raised_not_collected() -> None:
    """`to_ast` is the port the engine consumes, so it raises rather than listing."""
    with pytest.raises(HimarkSyntaxError):
        _to_ast("{a")


def test_a_contracting_line_carries_query_measure_and_template() -> None:
    """`<=>[@m]` is its own line kind: the pass pair plus the measure's name."""
    line = _line('{ba} <=>[@m] "ab"')
    assert isinstance(line, IterStatement)
    assert line.measure == "m"
    assert isinstance(line.query, Expr)
    assert isinstance(line.template, Template)


def test_a_measure_missing_its_sigil_is_a_syntax_error() -> None:
    """The bracket holds a declared name; a bare word names none."""
    with pytest.raises(HimarkSyntaxError, match="declared name"):
        _line('{a} <=>[m] "x"')


def test_mnemonic_escapes_spell_whitespace() -> None:
    r"""`\n` and `\t` spell the whitespace itself, not the letter after the slash."""
    assert _members(r"{\n,\t,\x}") == (
        Segments((Face("\n"),)),
        Segments((Face("\t"),)),
        Segments((Face("x"),)),
    )
