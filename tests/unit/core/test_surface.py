"""The surface AST is faithful: frozen, compared by value, and never normalized."""

from __future__ import annotations

import pytest

from hejmark.core.surface import (
    Expr,
    HimarkScopeError,
    Interp,
    Operand,
    Param,
    PipeItem,
    Ref,
    ScriptNode,
    Segments,
    Statement,
    Template,
    Text,
    UniDecl,
    Unit,
    UniverseNode,
)
from hejmark.core.syntax import Face


def test_scope_error_is_a_value_error() -> None:
    """Callers may catch a refused scope as a plain ValueError."""
    assert issubclass(HimarkScopeError, ValueError)


def test_nodes_are_frozen() -> None:
    """Surface nodes are immutable, so an expansion can never rewrite its input."""
    ref = Ref("spellings")
    with pytest.raises(AttributeError):
        ref.name = "other"  # ty: ignore[invalid-assignment]


def test_nodes_compare_by_value() -> None:
    """Two nodes spelling the same thing are equal, which is what tests lean on."""
    assert Unit(UniverseNode((Segments((Face("a"),)),))) == Unit(
        UniverseNode((Segments((Face("a"),)),))
    )
    assert Ref("") != Ref("0")


def test_bare_register_carries_the_empty_name() -> None:
    """``@`` is the head and ``@0`` its zero entry; the sigil is not part of the name."""
    assert Ref("").name == ""
    assert Ref("0").name == "0"


def test_a_unit_defaults_to_no_exponent_and_no_pipeline() -> None:
    """Most units are a bare base, so the optional parts default away."""
    unit = Unit(Ref("fill"))
    assert unit.exponent is None
    assert unit.pipeline == ()


def test_a_pipe_item_and_a_param_may_be_pairs() -> None:
    """``lo..hi`` is one item and one parameter, not two."""
    assert PipeItem("8", "12").hi == "12"
    assert Param("w", "w'").hi == "w'"
    assert PipeItem("where").hi is None


def test_a_script_holds_declarations_and_statements_in_source_order() -> None:
    """Order matters: a statement may use a name the line above declares."""
    decl = UniDecl("d", Expr((Unit(UniverseNode(())),)))
    stmt = Statement((Expr((Unit(Ref("d")),)),))
    assert ScriptNode((decl, stmt)).lines == (decl, stmt)


def test_a_template_holds_text_and_interpolation_sites() -> None:
    """Literal text and capture reads are distinct parts, in order."""
    template = Template((Text("<b>"), Interp("$"), Text("</b>")))
    assert [type(part).__name__ for part in template.parts] == ["Text", "Interp", "Text"]
    assert template.parts[1] == Interp("$")


def test_the_operand_token_carries_nothing() -> None:
    """``_`` is a token, not a value: what it binds to comes from the application."""
    assert Operand() == Operand()
