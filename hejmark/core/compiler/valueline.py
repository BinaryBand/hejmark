"""The value family ``@lo..hi``: the head's value line cut by value.

The cut is the one read no expression computes. An expression cuts spellings,
and cutting the value line with a spelling range is exact only where value
order and shortlex agree -- a premise about the digits' faces, not a theorem
about the language. Over a radix whose digits wear wider faces the two orders
part, so this module cuts by *position* instead.

Expansion is the bounded digit-walk. The head's entries in value order are the
radix's digits, so a bound decomposes into digit positions and the cut becomes
numerals narrower than the bound, plus one term per position carrying that
position's prefix, a cut of the digits below its digit, and free digits to the
right. Iterated product and union -- the five constructors, reached by counting
positions, which is the expander's arithmetic and never a denotation.

Both bounds are closure-free -- a numeral, always finite -- so the cut is a
finite union of numeral spellings and spends no closure; there is no open cut,
since ``@lo..`` has no reading.

The head is enumerated here the way :func:`hejmark.core.compiler.expand._zero`
enumerates it: the floor's own bounded range computes its successor at
expansion time, and reading the head's digits is that same move. Both reach
denotation through the engine's :data:`~hejmark.core.ir.program.ToFaces`, which
the caller carries in; this module denotes nothing itself.
"""

from itertools import islice, pairwise

from hejmark.core.floor import syntax
from hejmark.core.ir.errors import HimarkScopeError
from hejmark.core.ir.program import ToFaces

EMPTY = syntax.UniverseNode(())

# How many digits a head may offer before the cut is refused. A value cut needs
# the whole radix -- reading a bound means knowing every digit's position -- so
# an unbounded head has no radix at all and streaming it never returns. L2 makes
# that a diagnostic rather than a hang; the number is a host's choice, and this
# one sits far above any radix anyone writes (`{@hex}` is 16) and far below the
# code space a head like `{@char}` would offer.
RADIX_BUDGET = 4096


class ValueLineError(HimarkScopeError):
    """Raised when a bound the head radix does not spell is asked of a value cut."""


def digits(faces: ToFaces, head: syntax.UniverseNode) -> tuple[str, ...]:
    """The head radix's digits, canonical face per entry, in value order.

    The value family cuts the value axis and leaves the face axis to the stages
    that follow it, so each entry reads at its canonical face -- exactly what
    the bare ``@0`` register reads.

    Bounded by :data:`RADIX_BUDGET`, which is L2's contract here. The stream is
    lazy, so one digit past the budget is enough to know the head is offering
    more than a radix can be read from, and the cut is refused rather than left
    reading an unbounded head forever.

    Raises:
        ValueLineError: the head offers more than :data:`RADIX_BUDGET` digits.
    """
    found = tuple(islice(faces(head), RADIX_BUDGET + 1))
    if len(found) > RADIX_BUDGET:
        msg = f"a value cut needs a bounded radix; this head exceeds {RADIX_BUDGET} digits"
        raise ValueLineError(msg)
    return found


def value_of(spelling: str, alphabet: tuple[str, ...]) -> int:
    """Read a spelling as a numeral in the radix, returning its value.

    The split into digits takes the widest digit that lets the rest of the
    spelling split -- the matcher's maximal munch, run at expansion time over a
    finite alphabet, so a wider face wins over a prefix of itself.

    Raises:
        ValueLineError: the radix does not spell the numeral.
    """
    base = len(alphabet)
    if base == 0:
        msg = f"an empty head spells no numeral, so {spelling!r} is not a bound"
        raise ValueLineError(msg)
    index = {face: position for position, face in enumerate(alphabet)}
    widths = sorted({len(face) for face in alphabet}, reverse=True)

    # Slot i holds the value of spelling[:i], or None where no split reaches it.
    reached: list[int | None] = [0, *[None] * len(spelling)]
    for cut_at in range(1, len(spelling) + 1):
        for width in widths:
            start = cut_at - width
            if start < 0:
                continue
            carried = reached[start]
            position = index.get(spelling[start:cut_at])
            if carried is not None and position is not None:
                reached[cut_at] = carried * base + position
                break
    total = reached[len(spelling)]
    if total is None:
        msg = f"{spelling!r} is not a numeral in this radix"
        raise ValueLineError(msg)
    return total


def _positions(value: int, base: int) -> list[int]:
    """The canonical digit positions of a value, most significant first."""
    if value == 0:
        return [0]
    found: list[int] = []
    while value:
        value, remainder = divmod(value, base)
        found.append(remainder)
    return list(reversed(found))


def _span(alphabet: tuple[str, ...], stop: int, start: int = 0) -> syntax.UniverseNode:
    """The digits at values ``start`` up to but not including ``stop``."""
    return syntax.UniverseNode(tuple(syntax.Face(face) for face in alphabet[start:stop]))


def _factors(nodes: list[syntax.UniverseNode]) -> syntax.Member:
    """Adjacency is the product; a lone factor rides a one-factor product."""
    return syntax.Product(tuple(nodes))


def _narrower(alphabet: tuple[str, ...], width: int) -> list[syntax.Member]:
    """The canonical numerals of fewer than ``width`` digits: zero, then each width.

    Zero enters at every width, itself included: it is the one canonical
    numeral a leading-digit cut can never reach, since that cut starts at one.
    """
    everything = _span(alphabet, len(alphabet))
    nonzero = _span(alphabet, len(alphabet), 1)
    members: list[syntax.Member] = [syntax.Face(alphabet[0])]
    members.extend(_factors([nonzero, *[everything] * (count - 1)]) for count in range(1, width))
    return members


def _less_than(value: int, alphabet: tuple[str, ...]) -> syntax.UniverseNode:
    """The canonical numerals of the radix strictly below ``value``."""
    if value <= 0:
        return EMPTY
    base = len(alphabet)
    positions = _positions(value, base)
    width = len(positions)
    everything = _span(alphabet, base)
    members: list[syntax.Member] = _narrower(alphabet, width)
    prefix = ""
    for place, digit in enumerate(positions):
        # The leading digit never takes the zero: a canonical numeral of this
        # width has no leading zero, and the narrower widths already entered.
        cut_from = 1 if place == 0 else 0
        span = _span(alphabet, digit, cut_from)
        if span.members:
            nodes = [syntax.UniverseNode((syntax.Face(prefix),))] if prefix else []
            nodes.append(span)
            nodes.extend([everything] * (width - place - 1))
            members.append(_factors(nodes))
        prefix += alphabet[digit]
    return syntax.UniverseNode(tuple(members))


def _from_low(
    upper: syntax.UniverseNode, low: int, alphabet: tuple[str, ...]
) -> syntax.UniverseNode:
    """Strip the entries below ``low`` from a value line; ``low`` 0 strips nothing."""
    if low == 0:
        return upper
    return syntax.UniverseNode((*upper.members, syntax.Subtract(_less_than(low, alphabet))))


def _collapsed(alphabet: tuple[str, ...], low: int, high: int) -> syntax.UniverseNode | None:
    """The cut as one range, where value order and shortlex agree; else ``None``.

    L2's second permitted rewrite (``docs/foundation/L2.md``). Over
    single-code-point digits laid out consecutively in the code space the two
    orders are the same order, so a cut of a contiguous span of them *is* a
    contiguous range -- and the digit-walk below, which would build a union of
    numerals and subtract another to say the same thing, collapses to one node.

    The premise is checked, never assumed, which is why this is partial: the cut
    must stay inside single-digit numerals (``high`` below the radix), every
    digit it takes must be one code point, and they must be adjacent code points
    in value order. A radix whose digits wear wider faces, or one that skips
    around the code space, fails the check and walks.
    """
    if high >= len(alphabet):
        return None
    span = alphabet[low : high + 1]
    if any(len(face) != 1 for face in span):
        return None
    if any(ord(face) + 1 != ord(nxt) for face, nxt in pairwise(span)):
        return None
    return syntax.UniverseNode((syntax.Range(span[0], span[-1]),))


def cut(faces: ToFaces, head: syntax.UniverseNode, lo: str, hi: str) -> syntax.UniverseNode:
    """The head's value line cut to the entries at values ``lo`` through ``hi``.

    Both bounds are always given -- there is no open cut. Total in the floor's
    manner: ``hi`` below ``lo`` reads as the empty universe, and an empty head
    has no entries to cut. An unbounded head has no finite radix, so
    :func:`digits` refuses it rather than reading forever.

    Raises:
        ValueLineError: the head carries a bound it cannot spell, or offers more
            digits than a radix may.
    """
    alphabet = digits(faces, head)
    if not alphabet:
        return EMPTY
    low = value_of(lo, alphabet)
    high = value_of(hi, alphabet)
    if high < low:
        return EMPTY
    collapsed = _collapsed(alphabet, low, high)
    if collapsed is not None:
        return collapsed
    return _from_low(_less_than(high + 1, alphabet), low, alphabet)
