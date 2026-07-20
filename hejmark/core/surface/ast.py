"""Faithful abstract syntax tree for the L1.5 surface.

These nodes mirror ``HimarkParser.g4`` exactly: a script is lines, a line is a
declaration or a statement, a statement is steps joined by ``=>``. Nothing is
resolved here -- names stay names, the operand token stays a token, pipelines
stay flat item lists -- because L1.5's whole job is to *expand* into the floor,
and that happens in :mod:`hejmark.core.surface.expand`.

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

from dataclasses import dataclass

from hejmark.core.floor.syntax import Closure, Face, Final, Range


class HimarkScopeError(ValueError):
    """Raised when the surface refuses a scope: L1.5 is the layer that rejects.

    Unknown or cyclic name, malformed definition or arity, a register outside a
    definition body, an operand token no application binds, a capture read that
    no branch anchors. Emptiness is never one of these -- a query denoting the
    empty universe matches nothing and says so.
    """


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
class PipeItem:
    """One flat item of a pipeline bracket: a stage name or an argument.

    ``hi`` is set only for a pair written ``lo..hi``. Stage names and arguments
    lex alike; binding splits the flat list by each definition's arity.
    """

    lo: str
    hi: str | None = None


@dataclass(frozen=True)
class Unit:
    """One factor: a base, an optional ``^`` exponent, an optional pipeline.

    ``exponent`` is the raw text of a numeral or a parameter name; resolving it
    to a repetition count is the expander's job.
    """

    base: UniverseNode | Ref | Operand
    exponent: str | None = None
    pipeline: tuple[PipeItem, ...] = ()


# One adjacent piece of a member: a factor, the closure token, or a bare face.
Segment = Unit | Closure | Face


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


# A member of a surface brace group. Range and Final are the floor's own.
Member = Range | Final | Subtract | Segments


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
class Text:
    """Literal template text, escapes already resolved; a lone ``{`` is text too."""

    text: str


@dataclass(frozen=True)
class Interp:
    """An interpolation site ``{{...}}`` holding one capture read.

    ``capture`` is ``"$"`` (the hit as it hit) or ``"$0"`` (its canonical face).
    """

    capture: str


Part = Text | Interp


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


Line = UniDecl | DefDecl | Statement


@dataclass(frozen=True)
class ScriptNode:
    """A whole ``.hmk`` script: declarations and statements, in source order."""

    lines: tuple[Line, ...]
