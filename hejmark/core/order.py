"""The spelling order: shortlex over spellings, and symbolic windows of it.

L1 fixes the **spelling order** as shortlex (shorter first, ties by code point)
-- a well-order of type omega over the whole Unicode code space; surrogates ride
along by design, nothing is special-cased. This module realizes just what the
constructors need:

- :func:`spelling_key` compares spellings in shortlex.
- :func:`successor` steps to the unique next spelling, which is what turns an
  inclusive range endpoint into a half-open bound and walks a window lazily.
- :class:`Window` is a half-open shortlex interval ``[lo, hi)``; a range or a
  final segment denotes as one window, never materialized. An unbounded window
  (``hi`` is ``None``) still answers ``contains`` in finite time.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from collections.abc import Iterator

# The greatest code point: the one character with no in-length successor.
_MAX = 0x10FFFF


def spelling_key(s: str) -> tuple[int, str]:
    """Shortlex comparison key: shorter first, ties broken code point by code point."""
    return (len(s), s)


def successor(s: str) -> str:
    r"""Return the shortlex successor: the unique next spelling after ``s``.

    Increments the last non-maximal code point and zeroes everything after it;
    an all-maximal string rolls to ``"\x00" * (len(s) + 1)``. Total: every
    spelling has a successor, so the spelling order is walked one step at a time.
    """
    codes = [ord(c) for c in s]
    for i in range(len(codes) - 1, -1, -1):
        if codes[i] != _MAX:
            codes[i] += 1
            for j in range(i + 1, len(codes)):
                codes[j] = 0
            return "".join(chr(c) for c in codes)
    return "\x00" * (len(s) + 1)


@dataclass(frozen=True)
class Window:
    """A half-open shortlex window ``[lo, hi)``; ``hi`` is ``None`` when unbounded.

    A reversed window (``hi`` at or below ``lo``) is simply empty: ``contains``
    finds no member and iteration yields nothing.
    """

    lo: str
    hi: str | None

    def is_empty(self) -> bool:
        """Whether the window has no member."""
        return self.hi is not None and spelling_key(self.hi) <= spelling_key(self.lo)

    def contains(self, s: str) -> bool:
        """Whether ``s`` falls inside the window."""
        if spelling_key(s) < spelling_key(self.lo):
            return False
        return self.hi is None or spelling_key(s) < spelling_key(self.hi)

    def minus(self, cut: Window) -> list[Window]:
        """The parts of the window left after removing ``cut`` -- zero, one, or two."""
        left_hi = self.hi
        if self.hi is None or spelling_key(cut.lo) < spelling_key(self.hi):
            left_hi = cut.lo
        pieces = [Window(self.lo, left_hi)]
        if cut.hi is not None:
            pieces.append(Window(max(self.lo, cut.hi, key=spelling_key), self.hi))
        return [piece for piece in pieces if not piece.is_empty()]

    def __iter__(self) -> Iterator[str]:
        """Yield the members in spelling order (lazy; an unbounded window is infinite)."""
        s = self.lo
        while self.hi is None or spelling_key(s) < spelling_key(self.hi):
            yield s
            s = successor(s)
