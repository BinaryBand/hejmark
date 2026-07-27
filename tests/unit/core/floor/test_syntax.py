"""Tests for core.syntax: the faithful AST nodes."""

from __future__ import annotations

import dataclasses

import pytest

from hejmark.core.floor.syntax import (
    Closure,
    Face,
    Fold,
    HimarkSyntaxError,
    Product,
    Range,
    Subtract,
    UniverseNode,
)


def test_syntax_error_is_a_value_error() -> None:
    """Callers may catch a Himark parse failure as a plain ValueError."""
    assert issubclass(HimarkSyntaxError, ValueError)


def test_nodes_are_frozen() -> None:
    face = Face("a")
    with pytest.raises(dataclasses.FrozenInstanceError):
        face.text = "b"  # ty: ignore[invalid-assignment]


def test_nodes_compare_by_value() -> None:
    assert Face("a") == Face("a")
    assert Face("a") != Face("b")
    assert UniverseNode((Face("a"),)) == UniverseNode((Face("a"),))


def test_nodes_nest_without_normalizing() -> None:
    """The AST is faithful: a nested universe is preserved verbatim, not flattened."""
    inner = UniverseNode((Face("a"), Face("a")))
    outer = UniverseNode((Fold(inner), Range("0", "9"), Subtract(inner)))

    members = outer.members
    assert members[0] == Fold(inner)
    assert members[1] == Range("0", "9")
    assert members[2] == Subtract(inner)
    # The duplicate face survives: deduplication is denotation's job, not the AST's.
    assert inner.members == (Face("a"), Face("a"))


def test_product_holds_factors_in_order() -> None:
    """A product member keeps its factor sequence verbatim, `&` marks included."""
    left = UniverseNode((Face("a"),))
    right = UniverseNode((Face("b"),))
    product = Product((left, Closure(), right))

    assert product.factors == (left, Closure(), right)
    assert Closure() == Closure()
