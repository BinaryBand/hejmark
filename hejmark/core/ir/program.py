"""The Program: what the compiler emits and the engine executes.

Every class here is frozen data over ``str``, ``int``, tuples and the floor's
:class:`~hejmark.core.floor.syntax.UniverseNode` -- no environment, no surface
AST, no live universe. A back-referencing factor is the one thing the compiler
cannot lower ahead of a binding, so it crosses as a :class:`LateSlot` -- a hole
naming which factors it reads -- and the engine resolves it per attempt through
a :data:`LateResolver` callback the compiler provides. A slot-free program
never invokes the callback and is fully self-contained.

The boundary's two callbacks are both declared here, because a callback is a
thing both sides must name and neither may import across:
:data:`LateResolver` runs the compiler's expander from inside the engine, and
:data:`ToFaces` runs the engine's denotation from inside the compiler. Each is
injected by :mod:`hejmark.core.driver`, never imported by its caller.

The sentinel space also lives here: sentinel faces are a boundary fact (the
program carries the allocations), so the allocation base is defined where both
sides can see it.
"""

from __future__ import annotations

from collections.abc import Callable, Iterator
from dataclasses import dataclass

from hejmark.core.floor.syntax import UniverseNode

# Sentinel faces are allocated from the first noncharacter block, in
# declaration order, so allocation is deterministic and per-script.
SENTINEL_BASE = 0xFDD0


@dataclass(frozen=True)
class LateSlot:
    """A back-referencing factor: a hole resolved per attempt, once its reads bind.

    ``needs`` holds the 1-based indices of the factors it reads, in written
    order; the resolver receives exactly one bound face per entry.
    """

    slot: int
    needs: tuple[int, ...]


@dataclass(frozen=True)
class EagerFactor:
    """A factor lowered ahead of any binding: its floor form."""

    node: UniverseNode


QueryFactor = EagerFactor | LateSlot

# The run-time back edge: given a slot id and the faces bound to its reads --
# one per `needs` entry, in order -- return the floor form the substituted unit
# expands to. The compiler implements this; the engine only calls it.
LateResolver = Callable[[int, tuple[str, ...]], UniverseNode]

# The compile-time crossing, pointing the other way: given a floor node, stream
# the canonical face of each of its entries in declaration order. The engine
# implements this, denotation being its stratum; the compiler only calls it, and
# only where a surface construct is *defined* by a bounded read of what a
# universe denotes -- `@0` reads the head's zero entry, and a value cut reads the
# head radix's digits. Lazy by contract: a caller wanting the zero entry must
# pay for one entry, since a head may denote unboundedly many.
ToFaces = Callable[[UniverseNode], Iterator[str]]


@dataclass(frozen=True)
class CompiledQuery:
    """A query lowered to the floor: one factor per unit, eager or slotted.

    ``source`` is the written query, carried for diagnostics only -- nothing
    executes it.
    """

    source: str
    factors: tuple[QueryFactor, ...]


@dataclass(frozen=True)
class TextPart:
    """Literal template text, escapes already resolved."""

    text: str


@dataclass(frozen=True)
class CapturePart:
    """A capture read: ``"$"``, ``"$0"``, or ``"$k"`` exactly as written."""

    capture: str


@dataclass(frozen=True)
class SentinelPart:
    """A sentinel splice ``{{@name}}``, looked up in the program's table at render."""

    name: str


TemplatePart = TextPart | CapturePart | SentinelPart


@dataclass(frozen=True)
class CompiledTemplate:
    """A template as parts: literal text, capture reads, sentinel splices."""

    parts: tuple[TemplatePart, ...]


CompiledStep = CompiledQuery | CompiledTemplate


@dataclass(frozen=True)
class CompiledStatement:
    """One statement: steps joined by ``=>``, each a query or a template."""

    steps: tuple[CompiledStep, ...]


@dataclass(frozen=True)
class CompiledIter:
    """The contracting statement ``query <=> template``: iterated to a fixpoint."""

    query: CompiledQuery
    template: CompiledTemplate


CompiledLine = CompiledStatement | CompiledIter


@dataclass(frozen=True)
class Sentinel:
    """One sentinel allocation: a declared name and its noncharacter face."""

    name: str
    face: str


@dataclass(frozen=True)
class Program:
    """A compiled script: statements in source order plus the sentinel table."""

    statements: tuple[CompiledLine, ...]
    sentinels: tuple[Sentinel, ...]
