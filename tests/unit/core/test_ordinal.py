"""Tests for core.ordinal: Cantor-normal-form ordinals and the Horner sum.

Hand-computed cases pin the non-commutative arithmetic (``omega*2 != 2*omega``),
and :func:`horner` must reduce to plain integer mixed radix whenever every base
is finite -- a finite universe pays nothing.
"""

from __future__ import annotations

from Himark.core.ordinal import OMEGA, Ordinal, horner


def test_finite_results_are_plain_ints() -> None:
    assert OMEGA * 0 == 0
    assert isinstance(2 + 3, int)
    assert isinstance(Ordinal(((0, 2),)), Ordinal)  # constructed, but wrap keeps ints elsewhere


def test_addition_absorbs_lower_terms_on_the_left() -> None:
    assert 5 + OMEGA == OMEGA
    assert Ordinal(((1, 1), (0, 3))) == OMEGA + 3
    assert (OMEGA + 3) + OMEGA == OMEGA * 2


def test_multiplication_is_not_commutative() -> None:
    assert Ordinal(((1, 2),)) == OMEGA * 2
    assert 2 * OMEGA == OMEGA
    assert OMEGA * 2 != 2 * OMEGA


def test_multiplication_stacks_exponents() -> None:
    assert Ordinal(((2, 1),)) == OMEGA * OMEGA


def test_total_order() -> None:
    assert OMEGA > 7
    assert OMEGA < OMEGA + 1
    assert OMEGA + 1 < OMEGA * 2
    assert OMEGA * 2 < OMEGA * OMEGA


def test_str_is_ascii_cnf() -> None:
    assert str(OMEGA) == "w"
    assert str(OMEGA * 2) == "w*2"
    assert str(OMEGA * OMEGA * 3 + OMEGA + 4) == "w^2*3+w+4"


def test_int_of_finite_ordinal() -> None:
    assert int(Ordinal(((0, 5),))) == 5
    assert int(Ordinal(())) == 0


def test_horner_reduces_to_integer_mixed_radix() -> None:
    # {a,b,c}{a,b,c} on "cb": digit 2 then digit 1, base 3 -> 2*3 + 1 = 7.
    assert horner([3, 3], [2, 1]) == 7
    assert isinstance(horner([3, 3], [2, 1]), int)


def test_horner_places_base_powers_on_the_left() -> None:
    # {x,y}{a..}: bases (2, omega), values (m, n) -> omega*m + n.
    assert horner([2, OMEGA], [1, 4]) == OMEGA + 4
    assert horner([2, OMEGA], [0, 4]) == 4


def test_horner_single_position_is_the_value() -> None:
    assert horner([OMEGA + 1], [OMEGA]) == OMEGA
