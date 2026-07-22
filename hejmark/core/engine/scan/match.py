"""Leftmost-greedy matcher: set membership over spellings, nothing else.

A query is a product of factors. At each product position the matcher probes
prefixes of the remaining text longest-first (maximal munch): a candidate face
is a prefix of ``text[pos:]``, so there are at most ``len(text) - pos`` of
them, and a single ``contains`` accepts or rejects each. The first length that
lets the rest of the product match wins -- the canonical parse. The matcher
knows only spellings: no value or ordinal semantics leak in, and the empty
spelling is never accepted (no zero-width match).

A factor is a denoted universe -- or, where its unit back-references a factor
to its left, a :class:`Slot` awaiting the faces bound so far. The matcher
binds factors left to right, so at each position the slot's reads are bound
and it resolves -- through the compiler's
:data:`~hejmark.core.ir.program.LateResolver` callback -- into a plain
universe: every attempt is a floor query, which is the back-reference's whole
admission story. The exchange is pure data both ways (faces in, a floor node
out); the engine denotes and memoizes the answer here. The :class:`Query`
lives here rather than on the floor because a query may carry a slot, which
the floor cannot name.
"""

from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass, field

from hejmark.core.floor.reach import reach
from hejmark.core.floor.universe import Universe, denote
from hejmark.core.floor.work import budgeted
from hejmark.core.ir.errors import HimarkScopeError
from hejmark.core.ir.program import CompiledQuery, LateResolver, LateSlot


@dataclass(frozen=True)
class Slot:
    """A back-referencing factor at run time: the boundary's one back edge.

    ``needs`` mirrors the :class:`~hejmark.core.ir.program.LateSlot` it was
    loaded from; :meth:`at` projects the bound faces down to those reads,
    which is both the resolver's argument and the memo key -- two bindings
    agreeing on the reads resolve once. ``reach`` is the same slot's
    compile-time reach bound, carried unchanged for :mod:`capture`'s split
    search -- a read-only fact about the shape, not something resolving
    recomputes.
    """

    slot: int
    needs: tuple[int, ...]
    resolver: LateResolver
    reach: int | None = None
    _cache: dict[tuple[str, ...], Universe] = field(default_factory=dict, repr=False, compare=False)

    def at(self, bound: tuple[str, ...]) -> Universe:
        """Denote this factor under *bound*, the faces of the factors to its left."""
        key = tuple(bound[index - 1] for index in self.needs)
        if key not in self._cache:
            self._cache[key] = denote(self.resolver(self.slot, key))
        return self._cache[key]


@dataclass(frozen=True)
class Eager:
    """A factor denoted at load: its universe and the reach the compiler priced.

    The reach rides from :class:`~hejmark.core.ir.program.EagerFactor` rather
    than being measured here, so the engine reads a fact about the expression
    instead of deriving one. It is the same number
    :func:`~hejmark.core.floor.reach.reach` would return for ``universe.node``
    -- the compiler is simply the side that already asked.
    """

    universe: Universe
    reach: int | None = None


# One product position of a query: denoted, or awaiting its binding.
Factor = Eager | Slot


@dataclass(frozen=True)
class Query:
    """A denoted query: its source plus one factor per written unit, in order."""

    source: str
    universes: tuple[Factor, ...]

    def universe(self, index: int = 0) -> Universe:
        """The denoted universe at *index*, for callers that need one factor.

        Raises:
            HimarkScopeError: the factor back-references, so it denotes only
                under a binding -- resolve it with :func:`universe_at` instead.
        """
        factor = self.universes[index]
        if isinstance(factor, Slot):
            msg = f"factor {index + 1} back-references: it denotes only under a binding"
            raise HimarkScopeError(msg)
        return factor.universe


def load_query(compiled: CompiledQuery, resolver: LateResolver) -> Query:
    """Load a compiled query for matching: denote eager factors, wire the slots.

    The one place a program's data becomes live objects. Every slot in the
    loaded query shares *resolver*, and each keeps its own memo, so a face
    combination resolves once per load however many branches retry it. A
    slot-free query never calls the resolver at all.
    """
    return Query(
        compiled.source,
        tuple(
            Slot(factor.slot, factor.needs, resolver, factor.reach)
            if isinstance(factor, LateSlot)
            else Eager(denote(factor.node), factor.reach)
            for factor in compiled.factors
        ),
    )


def universe_at(factor: Factor, bound: tuple[str, ...]) -> Universe:
    """Resolve one factor under the faces bound to its left."""
    return factor.at(bound) if isinstance(factor, Slot) else factor.universe


@dataclass(frozen=True)
class MatchPart:
    """What matched at one product position: its span and the face that hit."""

    span: tuple[int, int]
    face: str


@dataclass(frozen=True)
class Match:
    """A whole match: its overall span and one part per product position."""

    span: tuple[int, int]
    parts: tuple[MatchPart, ...]


def _longest(factor: Factor, universe: Universe, remaining: int) -> int:
    """The longest span worth offering a factor: the text left, capped by its reach.

    A factor cannot wear a face longer than its expression reaches, so a longer
    span is a probe whose answer is already known. Where the expression is
    unbounded -- a final segment, a closure -- the remaining text is the only
    cap there is, which is the honest answer rather than a missing one.

    An eager factor carries the bound the compiler priced, so nothing is
    measured here. A slot cannot: its resolution is a fresh node per binding,
    so the bound comes off *that* node, which is tighter than the slot's own
    :attr:`Slot.reach` -- the latter has to hold for every binding, this one
    only for the binding in hand. That is the one place the matcher still reads
    the tree, and it is exactly the back edge's own footprint.
    """
    far = reach(universe.node) if isinstance(factor, Slot) else factor.reach
    return remaining if far is None else min(far, remaining)


@dataclass(frozen=True)
class _Search:
    """One query against one text, with the chart the attempts share.

    ``chart`` remembers what the product from a depth found at a position. The
    answer is a function of the factors, the text and the two indices -- L2's
    *equal questions have equal answers* -- so it stands for every start
    position and for every match of one scan, which is what keeps the whole
    scan from re-deriving the same tails.

    Not for a back-referencing factor, though: a :class:`Slot` denotes only
    under the faces bound to its left, so the same depth at the same position
    is not the same question twice. ``plain`` is the first depth whose tail
    carries no slot; only from there down does the chart apply.
    """

    factors: tuple[Factor, ...]
    text: str
    chart: dict[tuple[int, int], tuple[MatchPart, ...] | None]
    plain: int


def _plain(factors: tuple[Factor, ...]) -> int:
    """The first depth from which no factor back-references, so the chart holds."""
    late = [depth for depth, factor in enumerate(factors) if isinstance(factor, Slot)]
    return late[-1] + 1 if late else 0


def _try_product(
    search: _Search, pos: int, depth: int, bound: tuple[str, ...]
) -> tuple[MatchPart, ...] | None:
    """Match the product from ``depth`` onward at ``pos``; ``None`` if it can't."""
    if depth < search.plain:
        return _probe(search, pos, depth, bound)
    key = (depth, pos)
    if key not in search.chart:
        search.chart[key] = _probe(search, pos, depth, bound)
    return search.chart[key]


def _probe(
    search: _Search, pos: int, depth: int, bound: tuple[str, ...]
) -> tuple[MatchPart, ...] | None:
    """Try each face this factor could wear here, longest first, and recurse."""
    if depth == len(search.factors):
        return ()
    factor = search.factors[depth]
    universe = universe_at(factor, bound)
    for length in range(_longest(factor, universe, len(search.text) - pos), 0, -1):
        face = search.text[pos : pos + length]
        if not universe.contains(face):
            continue
        end = pos + length
        tail = _try_product(search, end, depth + 1, (*bound, face))
        if tail is not None:
            return (MatchPart((pos, end), face), *tail)
    return None


def _leftmost(search: _Search, start: int) -> Match | None:
    """Walk start positions left to right, returning the first that matches."""
    for pos in range(start, len(search.text) + 1):
        parts = _try_product(search, pos, 0, ())
        if parts is not None:
            end = parts[-1].span[1] if parts else pos
            return Match((pos, end), parts)
    return None


def _search(query: Query, text: str) -> _Search:
    """A fresh search: one chart per query and text, empty until an attempt fills it."""
    return _Search(query.universes, text, {}, _plain(query.universes))


def match(query: Query, text: str, start: int = 0) -> Match | None:
    """Return the leftmost match at or after ``start``, or ``None`` if there is none.

    Raises:
        HimarkBudgetError: the match ran past the host's work budget.
    """
    with budgeted("a match"):
        return _leftmost(_search(query, text), start)


def finditer(query: Query, text: str) -> Iterator[Match]:
    """Yield non-overlapping matches left to right, resuming past each span.

    One chart serves the whole scan: the text does not change between matches,
    so a tail derived for one match answers for the next. Each match carries its
    own work budget, unless an outer run -- a contracting pass -- holds one over
    the whole scan.

    Raises:
        HimarkBudgetError: a match ran past the host's work budget.
    """
    search = _search(query, text)
    pos = 0
    while True:
        with budgeted("a match"):
            found = _leftmost(search, pos)
        if found is None:
            return
        yield found
        pos = max(found.span[1], pos + 1)
