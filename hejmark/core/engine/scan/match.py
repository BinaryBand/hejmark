r"""Leftmost-greedy matcher: set membership over spellings, nothing else.

A query is a product of factors. At each product position the matcher probes
prefixes of the remaining text longest-first (maximal munch): a single
``contains`` accepts or rejects each, and the first length that lets the rest of
the product match wins -- the canonical parse. The matcher knows only spellings:
no value or ordinal semantics leak in, and the empty spelling is never accepted
(no zero-width match).

Which prefixes are offered is L2's reach rewrite (``docs/foundation/L2.md``),
read off the expression by :mod:`~hejmark.core.floor.reach`: a factor is never
offered a piece longer than the longest face it could wear, nor a cut leaving
the factors after it more text than they could ever cover. The matches are
identical -- only the probes are fewer, and on the language's idiomatic
``{{@x,&@x}}{\\!}`` the tail factor pins a whole scan of cuts to a single look.
A scan also opens a work budget, so a query that is polynomial but not
affordable is refused rather than waited on.

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

from hejmark.core.engine.budget import budgeted
from hejmark.core.engine.denote.universe import Universe, denote
from hejmark.core.floor.reach import reach
from hejmark.core.ir.errors import HimarkScopeError
from hejmark.core.ir.program import CompiledQuery, LateResolver, LateSlot


@dataclass(frozen=True)
class Slot:
    """A back-referencing factor at run time: the boundary's one back edge.

    ``needs`` mirrors the :class:`~hejmark.core.ir.program.LateSlot` it was
    loaded from; :meth:`at` projects the bound faces down to those reads,
    which is both the resolver's argument and the memo key -- two bindings
    agreeing on the reads resolve once.
    """

    slot: int
    needs: tuple[int, ...]
    resolver: LateResolver
    _cache: dict[tuple[str, ...], Universe] = field(default_factory=dict, repr=False, compare=False)

    def at(self, bound: tuple[str, ...]) -> Universe:
        """Denote this factor under *bound*, the faces of the factors to its left."""
        key = tuple(bound[index - 1] for index in self.needs)
        if key not in self._cache:
            self._cache[key] = denote(self.resolver(self.slot, key))
        return self._cache[key]


@dataclass(frozen=True)
class Eager:
    """A factor denoted at load: its universe."""

    universe: Universe


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
            Slot(factor.slot, factor.needs, resolver)
            if isinstance(factor, LateSlot)
            else Eager(denote(factor.node))
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


@dataclass(frozen=True)
class _Search:
    """One query against one text, with the chart the attempts share.

    ``chart`` remembers what the product from a depth found at a position. The
    answer is a function of the factors, the text and the two indices -- equal
    questions have equal answers -- so it stands for every start position and
    for every match of one scan, which is what keeps the whole scan from
    re-deriving the same tails.

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


def factor_reach(factor: Factor) -> int | None:
    """How long a face this query factor can wear, or ``None`` when unbounded.

    A :class:`Slot` is unbounded by construction: it denotes only under a
    binding, so nothing about the query alone bounds the face it will wear.
    Public because the re-split in :mod:`~hejmark.core.engine.scan.capture` cuts
    against the same bound.
    """
    return None if isinstance(factor, Slot) else reach(factor.universe.node)


def suffix_reach(factors: tuple[Factor, ...]) -> tuple[int | None, ...]:
    """How far each suffix of a query reaches: ``suffix_reach(f)[i]`` bounds ``f[i:]``.

    The query-level twin of :func:`~hejmark.core.floor.reach.suffixes`, which
    prices a floor product. It is a separate function only because a query
    factor may be a slot, which the floor cannot name.
    """
    tails: list[int | None] = [0]
    for factor in reversed(factors):
        far = factor_reach(factor)
        tail = tails[-1]
        tails.append(None if far is None or tail is None else far + tail)
    return tuple(reversed(tails))


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
    """Try each face this factor could wear here, longest first, and recurse.

    Reach fixes both ends of the range probed: the factor is offered nothing
    longer than it can wear, and nothing that leaves its tail more text than the
    tail can spell. Longest-first inside that range is still maximal munch, so
    the match chosen is the same one an unbounded probe would find.
    """
    if depth == len(search.factors):
        return ()
    factor = search.factors[depth]
    universe = universe_at(factor, bound)
    for length in reversed(_lengths(search, factor, pos)):
        face = search.text[pos : pos + length]
        if not universe.contains(face):
            continue
        end = pos + length
        tail = _try_product(search, end, depth + 1, (*bound, face))
        if tail is not None:
            return (MatchPart((pos, end), face), *tail)
    return None


def _lengths(search: _Search, factor: Factor, pos: int) -> range:
    """The face lengths worth trying at this position, ascending.

    Reach bounds this from above only. A match covers a *prefix* of the
    remaining text and may end anywhere, so what the factors after this one can
    spell says nothing about where this one must stop -- the lower bound that
    prices an exact tiling (:func:`~hejmark.core.floor.reach.cuts`, used by both
    split searches) has no counterpart here. The floor is one because the
    matcher accepts no zero-width part, where a product factor inside a universe
    may take one.
    """
    far = factor_reach(factor)
    remaining = len(search.text) - pos
    return range(1, (remaining if far is None else min(far, remaining)) + 1)


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
        HimarkBudgetError: the scan spent past the host's work budget.
        HimarkUnsettledError: a factor asked about absence in an unguarded
            closure, which no stage bounds.
    """
    with budgeted(f"the query {query.source!r}"):
        return _leftmost(_search(query, text), start)


def finditer(query: Query, text: str) -> Iterator[Match]:
    """The non-overlapping matches left to right, each resuming past the last.

    One chart serves the whole scan: the text does not change between matches,
    so a tail derived for one match answers for the next. One budget serves it
    too -- the scan is the run, not each match inside it -- so a query finding a
    thousand cheap matches is not charged as a thousand runs.

    The scan runs to the end before the first match is handed back, which is the
    budget's doing rather than a convenience: a meter is a run's, and a
    generator suspended at a yield would hold one open across whatever its
    caller did next, or leak it outright when abandoned mid-scan. A budgeted
    scan is finite by construction, so collecting what it found is bounded by
    the same number that bounds the scan. A caller wanting one match should ask
    for one -- :func:`match` is that question, and it is metered on its own.

    Raises:
        HimarkBudgetError: the scan spent past the host's work budget.
        HimarkUnsettledError: a factor asked about absence in an unguarded
            closure, which no stage bounds.
    """
    with budgeted(f"the query {query.source!r}"):
        search = _search(query, text)
        found: list[Match] = []
        pos = 0
        while (hit := _leftmost(search, pos)) is not None:
            found.append(hit)
            pos = max(hit.span[1], pos + 1)
    return iter(found)
