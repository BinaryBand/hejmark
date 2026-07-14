"""Minimal Cantor-normal-form ordinals for transfinite positional values.

FOUNDATION.md reads the positional formula in ordinal arithmetic once a base is
infinite: ``sum_i b^(k-1-i) * value(p_i)``, with the base power on the *left* so
that non-commutative multiplication (``omega*2 != 2*omega``) is respected. This
module carries just enough of the ordinals below ``omega^omega`` to evaluate
that sum:

- :class:`Ordinal` is a CNF sum ``sum_i w^(e_i) * c_i`` with strictly
  descending natural exponents and positive integer coefficients.
- :func:`horner` evaluates the theorem's mixed-radix sum most-significant-first.

Every operation keeps a *finite* result as a plain :class:`int`, so a finite
universe never pays for the ordinal machinery -- ordinals appear only once an
unbounded final segment makes a base actually infinite.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from collections.abc import Sequence

_Term = tuple[int, int]  # (exponent, coefficient), coefficient > 0


def _terms_of(x: int | Ordinal) -> tuple[_Term, ...]:
    """Coerce an ``int | Ordinal`` to its CNF term tuple."""
    if isinstance(x, Ordinal):
        return x.terms
    return ((0, x),) if x > 0 else ()


def _add(a: tuple[_Term, ...], b: tuple[_Term, ...]) -> tuple[_Term, ...]:
    """CNF ordinal addition: lower terms of ``a`` below ``b``'s lead are absorbed."""
    if not b:
        return a
    lead_exp = b[0][0]
    kept = tuple(t for t in a if t[0] > lead_exp)
    same = next((c for e, c in a if e == lead_exp), 0)
    if same:
        return (*kept, (lead_exp, same + b[0][1]), *b[1:])
    return (*kept, *b)


def _mul(a: tuple[_Term, ...], b: tuple[_Term, ...]) -> tuple[_Term, ...]:
    """CNF ordinal multiplication (non-commutative)."""
    if not a or not b:
        return ()
    lead_exp, lead_coeff = a[0]
    result: tuple[_Term, ...] = ()
    for exp, coeff in b:
        term = ((exp + lead_exp, coeff),) if exp > 0 else ((lead_exp, lead_coeff * coeff), *a[1:])
        result = _add(result, term)
    return result


@dataclass(frozen=True)
class Ordinal:
    """A Cantor-normal-form ordinal ``sum_i w^(e_i) * c_i``, exponents descending."""

    terms: tuple[_Term, ...]

    @staticmethod
    def _wrap(terms: tuple[_Term, ...]) -> int | Ordinal:
        """Return a plain ``int`` when the ordinal is finite, else an :class:`Ordinal`."""
        if not terms:
            return 0
        if len(terms) == 1 and terms[0][0] == 0:
            return terms[0][1]
        return Ordinal(terms)

    @property
    def is_finite(self) -> bool:
        """Whether the ordinal is a natural number (no infinite term)."""
        return all(exp == 0 for exp, _ in self.terms)

    def __add__(self, other: int | Ordinal) -> int | Ordinal:
        """Ordinal sum ``self + other``."""
        return Ordinal._wrap(_add(self.terms, _terms_of(other)))

    def __radd__(self, other: int | Ordinal) -> int | Ordinal:
        """Ordinal sum ``other + self`` (``other`` an ``int`` on the left)."""
        return Ordinal._wrap(_add(_terms_of(other), self.terms))

    def __mul__(self, other: int | Ordinal) -> int | Ordinal:
        """Ordinal product ``self * other`` (non-commutative)."""
        return Ordinal._wrap(_mul(self.terms, _terms_of(other)))

    def __rmul__(self, other: int | Ordinal) -> int | Ordinal:
        """Ordinal product ``other * self`` (``other`` an ``int`` on the left)."""
        return Ordinal._wrap(_mul(_terms_of(other), self.terms))

    def _cmp(self, other: int | Ordinal) -> int:
        a, b = self.terms, _terms_of(other)
        for (ea, ca), (eb, cb) in zip(a, b, strict=False):
            if ea != eb:
                return -1 if ea < eb else 1
            if ca != cb:
                return -1 if ca < cb else 1
        if len(a) == len(b):
            return 0
        return -1 if len(a) < len(b) else 1

    def __lt__(self, other: int | Ordinal) -> bool:
        """Whether ``self`` is strictly below ``other`` in the ordinal order."""
        return self._cmp(other) < 0

    def __le__(self, other: int | Ordinal) -> bool:
        """Whether ``self`` is at or below ``other`` in the ordinal order."""
        return self._cmp(other) <= 0

    def __gt__(self, other: int | Ordinal) -> bool:
        """Whether ``self`` is strictly above ``other`` in the ordinal order."""
        return self._cmp(other) > 0

    def __ge__(self, other: int | Ordinal) -> bool:
        """Whether ``self`` is at or above ``other`` in the ordinal order."""
        return self._cmp(other) >= 0

    def __int__(self) -> int:
        """The natural number this ordinal names, or :class:`OverflowError` if transfinite."""
        if not self.is_finite:
            msg = f"{self} is transfinite and has no integer value"
            raise OverflowError(msg)
        return self.terms[0][1] if self.terms else 0

    def __str__(self) -> str:
        """Render the ordinal in ASCII Cantor normal form (e.g. ``w^2*3+w+4``)."""
        if not self.terms:
            return "0"
        return "+".join(_term_str(exp, coeff) for exp, coeff in self.terms)


# omega, the first transfinite ordinal.
OMEGA = Ordinal(((1, 1),))


def _term_str(exp: int, coeff: int) -> str:
    """Render one CNF term ``w^exp * coeff`` in ASCII."""
    if exp == 0:
        return str(coeff)
    power = "w" if exp == 1 else f"w^{exp}"
    return power if coeff == 1 else f"{power}*{coeff}"


def horner(bases: Sequence[int | Ordinal], values: Sequence[int | Ordinal]) -> int | Ordinal:
    """Evaluate ``sum_i (prod_{j>i} bases[j]) * values[i]`` most-significant-first.

    Place values multiply from the left (``place * value``) so the sum stays
    faithful to ordinal arithmetic; a finite run keeps everything an ``int``.
    """
    places: list[int | Ordinal] = [1] * len(values)
    for i in range(len(values) - 2, -1, -1):
        places[i] = bases[i + 1] * places[i + 1]
    total: int | Ordinal = 0
    for place, value in zip(places, values, strict=True):
        total = total + place * value
    return total
