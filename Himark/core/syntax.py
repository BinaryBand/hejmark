"""Faithful abstract syntax tree for Himark source.

These nodes mirror the parse exactly: nothing is normalized, deduplicated, or
rewritten here. All constructor semantics (union no-ops, fold flattening,
subtraction, closure binding) happen later at denotation time in
:mod:`Himark.core.universe`.
"""

from __future__ import annotations

from dataclasses import dataclass


class HimarkSyntaxError(ValueError):
    """Raised when Himark source fails to lex or parse."""


@dataclass(frozen=True)
class Face:
    """A literal spelling; escapes are already resolved to their characters."""

    text: str


@dataclass(frozen=True)
class Range:
    """An inclusive character range `{lo..hi}` over single code points."""

    lo: str
    hi: str


@dataclass(frozen=True)
class Final:
    """A final segment `{a..}`: every spelling from `lo` onward in spelling order."""

    lo: str


@dataclass(frozen=True)
class Closure:
    """The self-reference token `&`: it reads the binder's previous stage."""


@dataclass(frozen=True)
class Fold:
    """A nested universe used as a member -- the quotient constructor."""

    universe: UniverseNode


@dataclass(frozen=True)
class Subtract:
    """A `!{...}` member stripping the faces its inner universe spells."""

    universe: UniverseNode


@dataclass(frozen=True)
class Product:
    """Adjacent factors as one member: tuples of entries, spelled by concatenation."""

    factors: tuple[UniverseNode | Closure, ...]


Member = Face | Range | Final | Fold | Subtract | Product | Closure


@dataclass(frozen=True)
class UniverseNode:
    """A brace group `{...}` with its members in declaration order."""

    members: tuple[Member, ...]


@dataclass(frozen=True)
class QueryNode:
    """A whole query: one or more universes juxtaposed as a product."""

    universes: tuple[UniverseNode, ...]
