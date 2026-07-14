"""The spelling order: shortlex over spellings, and symbolic interval sets.

FOUNDATION.md fixes the **spelling order** as shortlex (shorter first, ties by
code point) -- a well-order of type omega. This module realizes it three ways:

- :func:`spelling_index` places every spelling at its global shortlex position,
  a big integer; :func:`spelling_from_index` inverts it and :func:`successor`
  steps it by one. Together they make the order arithmetic rather than iterative.
- :class:`IntervalSet` is a normalized set of half-open shortlex intervals over
  those positions. A final segment or range denotes as an ``IntervalSet``; even
  an astronomically large finite range is a single interval, never materialized.

Every operation is derived from the integer positions, so a set that is infinite
(an unbounded final segment) still answers ``contains``/``rank`` in finite time.
"""

from __future__ import annotations

from dataclasses import dataclass

# Base of the shortlex enumeration: the whole Unicode code space, 0..0x10FFFF.
# Surrogates ride along by design (FOUNDATION.md); nothing is special-cased.
_N = 0x110000
_MAX = 0x10FFFF


def spelling_key(s: str) -> tuple[int, str]:
    """Shortlex comparison key: shorter first, ties broken code point by code point."""
    return (len(s), s)


def successor(s: str) -> str:
    r"""Return the shortlex successor: the unique next spelling after ``s``.

    Increments the last non-maximal code point and zeroes everything after it;
    an all-maximal string rolls to ``"\x00" * (len(s) + 1)``. Total: every
    spelling has a successor, so ``spelling_index(successor(s)) == index + 1``.
    """
    codes = [ord(c) for c in s]
    for i in range(len(codes) - 1, -1, -1):
        if codes[i] != _MAX:
            codes[i] += 1
            for j in range(i + 1, len(codes)):
                codes[j] = 0
            return "".join(chr(c) for c in codes)
    return "\x00" * (len(s) + 1)


def _shorter_count(length: int) -> int:
    """Number of spellings shorter than ``length``: the geometric sum sum_{j<len} N^j."""
    return (_N**length - 1) // (_N - 1) if length else 0


def spelling_index(s: str) -> int:
    """Return the global shortlex position of ``s`` (the empty spelling is 0)."""
    rank = 0
    for c in s:
        rank = rank * _N + ord(c)
    return _shorter_count(len(s)) + rank


def spelling_from_index(index: int) -> str:
    """Invert :func:`spelling_index`: the spelling at global shortlex position ``index``."""
    if index <= 0:
        return ""
    length = 1
    while not (_shorter_count(length) <= index < _shorter_count(length + 1)):
        length += 1
    rank = index - _shorter_count(length)
    digits: list[int] = []
    for _ in range(length):
        digits.append(rank % _N)
        rank //= _N
    return "".join(chr(d) for d in reversed(digits))


def _hi_val(hi: int | None) -> float | int:
    """Treat an unbounded upper endpoint (``None``) as positive infinity for comparison."""
    return float("inf") if hi is None else hi


def _subtract_one(
    plo: int, phi: int | None, olo: int, ohi: int | None
) -> list[tuple[int, int | None]]:
    """Return the parts of ``[plo, phi)`` left after removing ``[olo, ohi)``."""
    if _hi_val(ohi) <= plo or olo >= _hi_val(phi):
        return [(plo, phi)]
    out: list[tuple[int, int | None]] = []
    if olo > plo:
        out.append((plo, olo))
    if ohi is not None and _hi_val(phi) > ohi:
        out.append((ohi, phi))
    return out


@dataclass(frozen=True)
class IntervalSet:
    """A normalized set of disjoint half-open shortlex intervals over positions.

    Each interval is ``(lo, hi)`` in global shortlex positions, half-open
    ``[lo, hi)``; ``hi is None`` means unbounded (a final segment). The tuple is
    kept sorted, disjoint, and maximally merged, so equal sets compare equal.
    """

    intervals: tuple[tuple[int, int | None], ...]

    @staticmethod
    def empty() -> IntervalSet:
        """The empty set."""
        return IntervalSet(())

    @staticmethod
    def from_range(lo: str, hi: str | None) -> IntervalSet:
        """The half-open shortlex interval ``[lo, hi)`` (unbounded when ``hi`` is ``None``)."""
        lo_i = spelling_index(lo)
        hi_i = None if hi is None else spelling_index(hi)
        if hi_i is not None and hi_i <= lo_i:
            return IntervalSet.empty()
        return IntervalSet(((lo_i, hi_i),))

    @staticmethod
    def point(s: str) -> IntervalSet:
        """The singleton set ``{s}``."""
        i = spelling_index(s)
        return IntervalSet(((i, i + 1),))

    def is_empty(self) -> bool:
        """Whether the set has no members."""
        return not self.intervals

    def contains(self, s: str) -> bool:
        """Whether ``s`` is a member."""
        i = spelling_index(s)
        return any(lo <= i and (hi is None or i < hi) for lo, hi in self.intervals)

    def cardinality(self) -> int | None:
        """The number of members, or ``None`` when the set is infinite."""
        total = 0
        for lo, hi in self.intervals:
            if hi is None:
                return None
            total += hi - lo
        return total

    def rank(self, s: str) -> int:
        """The number of members strictly less than ``s`` (always finite)."""
        i = spelling_index(s)
        total = 0
        for lo, hi in self.intervals:
            if hi is not None and hi <= i:
                total += hi - lo
            elif lo < i:
                total += i - lo
        return total

    def nth(self, index: int) -> str:
        """The ``index``-th member in spelling order."""
        for lo, hi in self.intervals:
            size = None if hi is None else hi - lo
            if size is None or index < size:
                return spelling_from_index(lo + index)
            index -= size
        msg = "index out of range"
        raise IndexError(msg)

    def union(self, other: IntervalSet) -> IntervalSet:
        """The union of two sets, renormalized."""
        merged: list[tuple[int, int | None]] = []
        for lo, hi in sorted(self.intervals + other.intervals, key=lambda iv: iv[0]):
            if merged and lo <= _hi_val(merged[-1][1]):
                plo, phi = merged[-1]
                new_hi = None if (phi is None or hi is None) else max(phi, hi)
                merged[-1] = (plo, new_hi)
            else:
                merged.append((lo, hi))
        return IntervalSet(tuple(merged))

    def difference(self, other: IntervalSet) -> IntervalSet:
        """The members of this set not in ``other``."""
        result: list[tuple[int, int | None]] = []
        for lo, hi in self.intervals:
            pieces: list[tuple[int, int | None]] = [(lo, hi)]
            for olo, ohi in other.intervals:
                pieces = [part for plo, phi in pieces for part in _subtract_one(plo, phi, olo, ohi)]
            result.extend(pieces)
        return IntervalSet(tuple(result))

    def intersects(self, other: IntervalSet) -> bool:
        """Whether the two sets share any member."""
        return any(
            max(lo, olo) < _hi_val(_min_hi(hi, ohi))
            for lo, hi in self.intervals
            for olo, ohi in other.intervals
        )

    def __iter__(self):  # noqa: ANN204 -- Iterator[str], typed via return of a generator
        """Yield the members in spelling order (lazy; an unbounded set is infinite)."""
        for lo, hi in self.intervals:
            s = spelling_from_index(lo)
            index = lo
            while hi is None or index < hi:
                yield s
                s = successor(s)
                index += 1

    def __repr__(self) -> str:
        """Compact repr: a point interval is its spelling, a range is ``a..z``."""
        if not self.intervals:
            return "{}"
        parts = [_interval_repr(lo, hi) for lo, hi in self.intervals]
        return parts[0] if len(parts) == 1 else "{" + ",".join(parts) + "}"


def _interval_repr(lo: int, hi: int | None) -> str:
    """The compact spelling of a single half-open interval ``[lo, hi)``."""
    lo_s = spelling_from_index(lo)
    if hi is None:
        return f"{lo_s}.."
    if hi - lo == 1:
        return lo_s
    return f"{lo_s}..{spelling_from_index(hi - 1)}"


def _min_hi(a: int | None, b: int | None) -> int | None:
    """The smaller of two upper endpoints, treating ``None`` as infinity."""
    if a is None:
        return b
    if b is None:
        return a
    return min(a, b)
