"""The Program: what the compiler emits and the engine executes.

Every class here is frozen data over ``str``, ``int``, tuples and the floor's
:class:`~hejmark.core.floor.syntax.UniverseNode` -- no environment, no surface
AST, no live universe. A back-referencing factor is the one thing the compiler
cannot lower ahead of a binding, so it crosses as a :class:`LateSlot` -- a hole
naming which factors it reads -- and the engine resolves it per attempt through
a :data:`LateResolver` callback the compiler provides. A slot-free program
never invokes the callback and is fully self-contained.

The sentinel space also lives here: sentinel faces are a boundary fact (the
program carries the allocations, the engine's exit guard reads the space), so
:func:`noncharacter` and the allocation base are defined where both sides can
see them.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass

from hejmark.core.floor.syntax import UniverseNode

# Sentinel faces are allocated from the first noncharacter block, in
# declaration order, so allocation is deterministic and per-script. The other
# noncharacters are the last two code points of every plane.
SENTINEL_BASE = 0xFDD0
_SENTINEL_TOP = 0xFDEF
_PLANE_ENDER = 0xFFFE


def noncharacter(char: str) -> bool:
    """Whether *char* is one of Unicode's noncharacters -- the sentinel space.

    The seeded ``C`` subtracts these, so no ``@C``-derived universe can touch a
    sentinel: only its declared name matches it.
    """
    point = ord(char)
    return SENTINEL_BASE <= point <= _SENTINEL_TOP or point & _PLANE_ENDER == _PLANE_ENDER


@dataclass(frozen=True)
class LateSlot:
    """A back-referencing factor: a hole resolved per attempt, once its reads bind.

    ``needs`` holds the 1-based indices of the factors it reads, in written
    order; the resolver receives exactly one bound face per entry.
    """

    slot: int
    needs: tuple[int, ...]


QueryFactor = UniverseNode | LateSlot

# The one back edge: given a slot id and the faces bound to its reads -- one
# per `needs` entry, in order -- return the floor form the substituted unit
# expands to. The compiler implements this; the engine only calls it.
LateResolver = Callable[[int, tuple[str, ...]], UniverseNode]


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
    """The contracting statement ``query <=>[@m] template``.

    The measure is expanded at compile time; ``measure_name`` survives for the
    engine's diagnostics.
    """

    query: CompiledQuery
    measure_name: str
    measure: UniverseNode
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
