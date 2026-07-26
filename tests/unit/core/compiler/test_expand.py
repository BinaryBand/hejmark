"""Expansion: every surface construct reaches the floor's five constructors.

The assertions read the *expanded* tree rather than its denotation, because
that is what expansion promises: what comes out is a plain ``core.syntax``
node, with nothing of L1.5 left in it.
"""

from __future__ import annotations

import pytest

from hejmark.adapters.library import standard_library
from hejmark.adapters.parser import AntlrParser
from hejmark.core.compiler.ast import Expr, Statement
from hejmark.core.compiler.expand import UNIT, Ctx, expand
from hejmark.core.compiler.prelude import prelude_env
from hejmark.core.compiler.resolve import collect, merge
from hejmark.core.engine.denote.universe import canonical_faces, denote
from hejmark.core.floor import syntax
from hejmark.core.ir.errors import HimarkScopeError

_to_ast = AntlrParser().to_ast


def _expr(source: str) -> Expr:
    """The single query expression a one-line script holds."""
    line = _to_ast(source).lines[0]
    assert isinstance(line, Statement)
    step = line.steps[0]
    assert isinstance(step, Expr)
    return step


def _expand(source: str, declarations: str = "") -> syntax.UniverseNode:
    """Expand a query written under some declarations, over the seeded std."""
    env = merge(prelude_env(_to_ast, standard_library()), collect(_to_ast(declarations)))
    factors = expand(_expr(source), Ctx(env, canonical_faces))
    return factors[0] if len(factors) == 1 else syntax.UniverseNode((syntax.Product(factors),))


def test_a_plain_universe_expands_to_itself() -> None:
    """L1 written directly is already expanded; nothing is rewritten."""
    assert _expand("{a,b}") == syntax.UniverseNode((syntax.Face("a"), syntax.Face("b")))


def test_a_range_survives() -> None:
    """Compression is the floor's, so the surface passes a range straight through."""
    assert _expand("{a..z}") == syntax.UniverseNode((syntax.Range("a", "z"),))


def test_a_brace_group_member_is_the_fold() -> None:
    """A braced member quotients; that is the fold constructor, not a splice."""
    expanded = _expand("{{cat,feline}}")
    assert isinstance(expanded.members[0], syntax.Fold)


def test_adjacent_segments_are_the_product() -> None:
    """Adjacency is the product, flat rather than nested."""
    expanded = _expand("{{a}{b}}")
    member = expanded.members[0]
    assert isinstance(member, syntax.Product)
    assert len(member.factors) == 2


def test_a_name_splices_rather_than_folds() -> None:
    """A splice spreads entry-wise where a braced member quotients."""
    expanded = _expand("{@pair}", "uni pair = {a,b}")
    assert expanded == syntax.UniverseNode((syntax.Face("a"), syntax.Face("b")))


def test_a_spliced_binder_stays_braced() -> None:
    """Inlining a binder's members would rebind ``&`` to the enclosing brace."""
    expanded = _expand("{@loop}", "uni loop = {a,&{b}}")
    assert isinstance(expanded.members[0], syntax.Fold)


def test_an_exponent_repeats_a_factor() -> None:
    """``A^n`` is n copies; the count is read off the numeral."""
    expanded = _expand("{@c^3}", "uni c = {a}")
    member = expanded.members[0]
    assert isinstance(member, syntax.Product)
    assert len(member.factors) == 3


def test_a_zero_exponent_is_the_unit() -> None:
    """``A^0`` is well-formed: the unit is the product identity."""
    assert _expand("{@c^0}", "uni c = {a}").members[0] == syntax.Fold(syntax.UniverseNode(()))


def test_a_non_numeral_exponent_is_refused() -> None:
    """Every exponent the surface writes is a plain count, so a spelling is refused."""
    with pytest.raises(HimarkScopeError, match="decimal numeral"):
        _expand("{@c^x}", "uni c = {a}")


def test_a_register_outside_a_definition_body_is_refused() -> None:
    """Registers read the pipeline head; with no head there is nothing to read."""
    with pytest.raises(HimarkScopeError, match="outside a definition body"):
        _expand("{@}", "uni d = {a}")


def test_the_operand_token_outside_an_application_is_refused() -> None:
    """``_`` binds only at application, never by inheritance."""
    with pytest.raises(HimarkScopeError, match="operand token"):
        _expand("{_}", "uni d = {a}")


def test_the_zero_register_reads_the_head() -> None:
    """``@0`` is the head's zero entry, which is what a fill is built on."""
    expanded = _expand("{0..9}[fill]")
    assert isinstance(expanded.members[0], syntax.Fold)


def test_chained_brackets_repoint_the_head() -> None:
    """Each bracket re-points the head to its left operand, unlike a fused pipeline.

    ``drop`` cuts the head's zero entry and ``z`` reads it, both off the head.
    Chained, ``z``'s head is ``drop``'s output ``{4,5}``; fused, both read the
    written head ``{3,4,5}``, so ``z`` sees ``3`` however ``drop`` moved the pipe.
    """
    defs = "def drop = {@,!{@0}}\ndef z = {@0}"
    chained = denote(_expand("{3,4,5}[drop][z]", defs))
    fused = denote(_expand("{3,4,5}[drop z]", defs))
    assert [entry.faces[0] for entry in chained.entries()] == ["4"]
    assert [entry.faces[0] for entry in fused.entries()] == ["3"]


def test_the_unit_is_a_fold_over_the_empty_alphabet() -> None:
    """The unit's shape is fixed, since a fill on an empty head must no-op onto it."""
    assert syntax.UniverseNode((syntax.Fold(syntax.UniverseNode(())),)) == UNIT


def test_a_read_inside_a_declaration_is_refused() -> None:
    """A read never crosses a declaration: a spliced `{$1}` has no query to bind in."""
    with pytest.raises(HimarkScopeError, match="through a declaration"):
        _expand("{@x}", "uni x = {$1}")


def test_a_read_argument_inside_a_definition_body_is_refused() -> None:
    """The argument case is refused on the same rule as the pattern case."""
    with pytest.raises(HimarkScopeError, match="through a declaration"):
        _expand("{@f}", "def f = {0..9}[where 0..$2]")
