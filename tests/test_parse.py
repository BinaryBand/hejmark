"""Tests for the parser adapter: faithful AST construction and syntax-error detection.

The parser (:func:`Himark.adapters.parser.to_ast`) builds a pure
:mod:`Himark.core.syntax` AST; these tests verify it preserves source structure
faithfully and correctly rejects invalid input.
"""

from __future__ import annotations

import pytest

from Himark.adapters.parser import to_ast
from Himark.core.syntax import Face, Fold, HimarkSyntaxError


def test_faithful_ast_preserves_nested_fold() -> None:
    """``{a,{a,A}}`` keeps the nested Fold node -- no flattening at parse time."""
    ast = to_ast("{a,{a,A}}")
    members = ast.universes[0].members
    assert len(members) == 2
    assert isinstance(members[0], Face)
    assert members[0].text == "a"
    assert isinstance(members[1], Fold)
    inner_members = members[1].universe.members
    assert isinstance(inner_members[0], Face)
    assert inner_members[0].text == "a"
    assert isinstance(inner_members[1], Face)
    assert inner_members[1].text == "A"


def test_escapes_yield_literal_braces() -> None:
    """``{\\{,\\!}`` yields faces ``{`` and ``!``."""
    ast = to_ast("{\\{,\\!}")
    members = ast.universes[0].members
    assert len(members) == 2
    assert isinstance(members[0], Face)
    assert members[0].text == "{"
    assert isinstance(members[1], Face)
    assert members[1].text == "!"


def test_dot_inside_face_is_literal_character() -> None:
    """``{a.b}`` is one face spelled ``a.b``, not a range."""
    ast = to_ast("{a.b}")
    members = ast.universes[0].members
    assert len(members) == 1
    assert isinstance(members[0], Face)
    assert members[0].text == "a.b"


def test_range_with_multi_char_endpoint_is_syntax_error() -> None:
    """``{ab..z}`` raises :class:`HimarkSyntaxError` because range endpoints are
    single characters."""
    with pytest.raises(HimarkSyntaxError):
        to_ast("{ab..z}")


def test_bare_bang_outside_brace_is_syntax_error() -> None:
    """A bare ``!`` outside ``!{`` raises :class:`HimarkSyntaxError`."""
    with pytest.raises(HimarkSyntaxError):
        to_ast("!")

    with pytest.raises(HimarkSyntaxError):
        to_ast("a!")

    with pytest.raises(HimarkSyntaxError):
        to_ast("{a}!{b}")


def test_empty_braces_parse() -> None:
    """``{}`` parses to an empty universe (no members)."""
    ast = to_ast("{}")
    assert len(ast.universes) == 1
    assert len(ast.universes[0].members) == 0


def test_empty_universe_within_braces_parses() -> None:
    """``{a,{}}`` parses -- Fold of empty universe is a valid member."""
    ast = to_ast("{a,{}}")
    assert len(ast.universes[0].members) == 2
    assert isinstance(ast.universes[0].members[0], Face)
    assert isinstance(ast.universes[0].members[1], Fold)
