"""Where a closure binds."""

from __future__ import annotations

from hejmark.core.floor.binder import binds, free_amp
from hejmark.core.floor.syntax import (
    Closure,
    Face,
    Fold,
    Product,
    Subtract,
    UniverseNode,
)


def _node(*members):
    return UniverseNode(tuple(members))


def test_a_bare_amp_binds_its_enclosing_braces():
    assert binds(_node(Face("a"), Closure()))
    assert not binds(_node(Face("a"), Face("b")))


def test_an_amp_inside_a_product_still_binds():
    assert binds(_node(Product((_node(Face("a")), Closure()))))


def test_a_subtractions_braces_never_bind_so_the_amp_reads_the_outer_binder():
    # `&` inside `!{...}` is free in the subtraction but bound outside it: the
    # subtraction reports the amp upward rather than capturing it.
    inner = _node(Closure())
    assert free_amp(Subtract(inner))
    assert binds(_node(Face("a"), Subtract(inner)))


def test_a_fold_does_capture_its_own_amp():
    # Unlike a subtraction, a fold is a binder in its own right, so the amp is
    # not free in the enclosing expression.
    assert not binds(_node(Face("a"), Fold(_node(Closure()))))
