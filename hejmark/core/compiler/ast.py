"""Faithful abstract syntax tree for the L1.5 surface.

These nodes mirror ``HimarkParser.g4`` exactly: a script is lines, a line is a
declaration or a statement, a statement is steps joined by ``=>``. Nothing is
resolved here -- names stay names, the operand token stays a token, pipelines
stay flat item lists -- because L1.5's whole job is to *expand* into the floor,
and that happens in :mod:`hejmark.core.compiler.expand`.

The floor's own nodes are reused wherever the surface adds nothing:
:class:`~hejmark.core.floor.syntax.Face`, :class:`~hejmark.core.floor.syntax.Range`,
:class:`~hejmark.core.floor.syntax.Final` and :class:`~hejmark.core.floor.syntax.Closure`
mean here exactly what they mean there. Everything else is surface-only and
must be gone by the time :func:`hejmark.core.floor.universe.denote` is called.

Two normalizations happen at build time rather than here, both purely
syntactic: escapes resolve to their characters (as on the floor), and a braced
exponent ``^{w'}`` unwraps to the parameter name it spells, which the grammar
comment already reads as one thing.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from hejmark.core.floor.syntax import Closure, Face, Final, Range

# The factor family's spelling, exactly: 1-based, no leading zero. Pipeline
# arguments keep their raw text, so a read standing as one is re-recognized by
# this pattern; only the exact spelling ever lexes as a read, so the match is
# faithful.
_READ = re.compile(r"^\$([1-9][0-9]*)$")


def read_index(text: str) -> int | None:
    """The factor a ``$k`` spelling reads, or ``None`` if *text* is no read."""
    matched = _READ.match(text)
    return int(matched.group(1)) if matched else None


@dataclass(frozen=True)
class Ref:
    """A reference ``@name``; bare ``@`` and ``@0`` are the reserved registers.

    ``name`` is the text after the sigil, so bare ``@`` carries ``""`` and the
    zero-entry register carries ``"0"``. Numerals are not declarable, which is
    what keeps ``@0`` free.
    """

    name: str


@dataclass(frozen=True)
class Operand:
    """The operand token ``_``: the pipeline stage's incoming universe.

    It binds only at application. A definition invoked bare inside another body
    shares the caller's head but receives no operand, so a ``_`` in its body is
    a scope error, never an inheritance.
    """


@dataclass(frozen=True)
class Open:
    """The absent high bound of a value cut: ``@lo..`` / ``where lo..``.

    Distinct from ``hi=None`` on a :class:`PipeItem`, which is a lone numeral
    binding the degenerate pair ``n..n``; an open pair cuts the whole value tail
    from ``lo`` on, the value line's open case.
    """


# The one open-bound marker; there is nothing to distinguish between instances.
OPEN = Open()


@dataclass(frozen=True)
class PipeItem:
    """One flat item of a pipeline bracket: a stage name or an argument.

    ``hi`` is a spelling only for a pair written ``lo..hi``; :data:`OPEN` for an
    open pair ``lo..``; ``None`` for a lone item. Stage names and arguments lex
    alike; binding splits the flat list by each definition's arity.
    """

    lo: str
    hi: str | Open | None = None


@dataclass(frozen=True)
class Unit:
    """One factor: a base, an optional ``^`` exponent, an optional pipeline.

    ``exponent`` is the raw text of a numeral or a parameter name; resolving it
    to a repetition count is the expander's job.
    """

    base: UniverseNode | Ref | Operand
    exponent: str | None = None
    pipeline: tuple[PipeItem, ...] = ()


@dataclass(frozen=True)
class Read:
    """A back-reference ``$k`` standing in a pattern: factor ``k``, as it hit.

    It reads a factor of the same query, strictly to its left; the matcher
    binds factors left to right, so by the time the reading factor is tried
    its read is bound and the face substitutes as a literal spelling. A read
    inside a declaration stands in no query and is refused at expansion.
    """

    index: int


# One adjacent piece of a member: a factor, the closure token, a bare face, or
# a back-reference.
Segment = Unit | Closure | Face | Read


@dataclass(frozen=True)
class Segments:
    """A member built from adjacent segments.

    Arity does not classify it here the way it does on the floor: ``@shorter w``
    is an application and ``{a}{b}`` a product, and only binding knows which.
    """

    segments: tuple[Segment, ...]


@dataclass(frozen=True)
class Subtract:
    """A ``!{...}`` member stripping the faces its inner universe spells."""

    universe: UniverseNode


@dataclass(frozen=True)
class ValueCut:
    """The value family ``@lo..hi``: the head's value line cut by value.

    ``@0`` is the degenerate ``@0..0``, spelled as the bare register the way a
    lone numeral argument keeps ``n..n``. Both bounds are spellings in the head
    radix -- a written numeral, or a parameter naming one -- and ``hi`` may be a
    :class:`Read` standing as one, which is how ``where 0..$2`` reaches here, or
    :data:`OPEN` for the open case ``@lo..``: the whole value tail from ``lo``.

    Expansion is the digit-walk, which cuts by position rather than by
    spelling, so the cut is exact over any radix; the open case is the closure
    that generates the value line, minus ``lo``'s finite predecessors.
    """

    lo: str
    hi: str | Read | Open


# A member of a surface brace group. Range and Final are the floor's own.
Member = Range | Final | Subtract | Segments | ValueCut


@dataclass(frozen=True)
class UniverseNode:
    """A surface brace group ``{...}`` with its members in declaration order."""

    members: tuple[Member, ...]


@dataclass(frozen=True)
class Expr:
    """A product of units: adjacency is the product, a lone unit the singleton."""

    units: tuple[Unit, ...]


@dataclass(frozen=True)
class Param:
    """A definition parameter: an identifier, or an identifier pair ``lo..hi``."""

    lo: str
    hi: str | None = None


@dataclass(frozen=True)
class UniDecl:
    """A declaration ``uni name = expr``: the name stands wherever a universe stands."""

    name: str
    expr: Expr


@dataclass(frozen=True)
class DefDecl:
    """A definition ``name params := body``, applied through a modifier pipeline."""

    name: str
    params: tuple[Param, ...]
    expr: Expr


@dataclass(frozen=True)
class SentinelDecl:
    """A declaration ``sentinel name``: one entry wearing one host-allocated face.

    The face is a noncharacter the resolver allocates, so it carries no body
    here; resolution turns the name into an ordinary ``uni`` over a lone face.
    """

    name: str


@dataclass(frozen=True)
class Text:
    """Literal template text, escapes already resolved; a lone ``{`` is text too."""

    text: str


@dataclass(frozen=True)
class Interp:
    """An interpolation site ``{{...}}`` holding one capture read.

    ``capture`` is ``"$"`` (the hit as it hit), ``"$0"`` (its canonical face),
    or ``"$k"`` for ``k >= 1`` (factor ``k`` of the hit, as it hit -- one read
    per written top-level factor, 1-based since ``$0`` is taken).
    """

    capture: str


@dataclass(frozen=True)
class RefInterp:
    """An interpolation site ``{{@name}}`` reading a declared sentinel's face.

    ``name`` is the text after the sigil, as on :class:`Ref`. The read is of
    the environment, not the hit, which is what keeps it off the register
    inventory; a name that declares no sentinel is a scope error at emit.
    """

    name: str


Part = Text | Interp | RefInterp


@dataclass(frozen=True)
class Template:
    """A quoted template: literal text plus interpolation sites."""

    parts: tuple[Part, ...]


# A step is a query (a universe expression) or a template.
Step = Expr | Template


@dataclass(frozen=True)
class Statement:
    """A chain of steps joined by ``=>``; arrows are top-level only."""

    steps: tuple[Step, ...]


@dataclass(frozen=True)
class IterStatement:
    """A contracting statement ``query <=>[@m] template``: passes to settlement.

    The pass is the ordinary two-step statement, re-run until it finds nothing
    to rewrite. ``measure`` names a declared universe (the text after the
    sigil); each pass must leave the document strictly earlier in its entry
    order, which is what makes the iteration settle -- and a pass that fails
    to shrink it is a scope error at emit, never a silent stall.
    """

    query: Expr
    measure: str
    template: Template


Line = UniDecl | DefDecl | SentinelDecl | Statement | IterStatement


@dataclass(frozen=True)
class ScriptNode:
    """A whole ``.hmk`` script: declarations and statements, in source order."""

    lines: tuple[Line, ...]
