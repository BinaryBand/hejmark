"""Where a closure binds, and whether it settles."""

from __future__ import annotations

from hejmark.core.floor.binder import binds, free_amp, settled
from hejmark.core.floor.syntax import (
    Closure,
    Face,
    Fold,
    Product,
    Range,
    Subtract,
    UniverseNode,
)


def _node(*members):
    return UniverseNode(tuple(members))


def _spells_empty(node):
    """A stand-in oracle: a node spells "" exactly when it holds an empty face."""
    return Face("") in node.members


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


def test_a_bare_amp_is_unsettled():
    assert not settled(_node(Face("a"), Closure()), _spells_empty)


def test_an_amp_guarded_by_a_non_empty_factor_settles():
    guarded = _node(Product((_node(Face("a")), Closure())))
    assert settled(guarded, _spells_empty)


def test_an_amp_whose_only_sibling_can_be_empty_does_not_settle():
    # Nothing forces the pass to lengthen, so there is no stage bound.
    unguarded = _node(Product((_node(Face("")), Closure())))
    assert not settled(unguarded, _spells_empty)


def test_one_guarding_factor_is_enough():
    mixed = _node(Product((_node(Face("")), _node(Face("b")), Closure())))
    assert settled(mixed, _spells_empty)


def test_settledness_reaches_through_a_subtraction():
    assert not settled(_node(Face("a"), Subtract(_node(Closure()))), _spells_empty)


def test_members_with_no_amp_at_all_are_vacuously_settled():
    assert settled(_node(Face("a"), Range("a", "z")), _spells_empty)
