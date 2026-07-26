"""The L1.5 name environment: declarations, acyclicity, and pipeline binding.

A script's declarations are collected once into an :class:`Env`. Names live in
one namespace -- ``uni`` declarations and ``def`` definitions cannot collide --
and the registers are its reserved names, so neither may be declared.

Acyclicity is checked here rather than discovered as a recursion depth: `&` is
the language's only self-reference and it lives on the floor, so a name that
reaches itself is a diagnostic. That check is what makes expansion terminate.
It is a topological sort that never sorts: :func:`graphlib.TopologicalSorter`
validates the reference graph and reports the offending path, so the error
names the whole cycle rather than one arbitrary name on it.

Binding is the other half. A pipeline bracket lexes as a flat list of items
(stage names and arguments lex alike), and only arity tells them apart: each
stage name is followed by exactly as many items as its definition has
parameters. A pair parameter takes one item, which may be written ``lo..hi``
or -- the degenerate case -- a lone numeral standing for ``n..n``.
"""

from __future__ import annotations

import graphlib
from collections.abc import Iterator
from dataclasses import dataclass, field

from hejmark.core.compiler.ast import (
    DefDecl,
    Expr,
    IterStatement,
    Member,
    PipeItem,
    Ref,
    ScriptNode,
    Segments,
    SentinelDecl,
    Statement,
    Subtract,
    UniDecl,
    Unit,
    UniverseNode,
)
from hejmark.core.floor.syntax import Face
from hejmark.core.ir.errors import HimarkScopeError
from hejmark.core.ir.program import SENTINEL_BASE

# The reserved names: bare `@` is the head, `@0` its zero entry. Numerals are
# not declarable, which is what keeps `@0` free.
RESERVED = frozenset({"", "0"})

# At most this many sentinels per script; allocation walks the block that
# starts at the boundary's SENTINEL_BASE, in declaration order.
SENTINEL_LIMIT = 32


@dataclass(frozen=True)
class Binding:
    """One bound parameter: a spelling, or a pair of them.

    ``hi`` is ``None`` for a lone item, which binds a pair parameter as the
    degenerate ``n..n``; there is no open pair, since ``lo..`` has no reading.
    """

    lo: str
    hi: str | None = None


@dataclass(frozen=True)
class Stage:
    """One bound pipeline stage: a definition and its literal arguments."""

    definition: DefDecl
    arguments: tuple[Binding, ...]


@dataclass(frozen=True)
class Env:
    """The resolved namespace: ``uni`` declarations and ``def`` definitions.

    ``sentinels`` maps each ``sentinel`` name to its allocated face; the name
    also enters ``unis`` over that lone face, so patterns need no extra path.
    """

    unis: dict[str, Expr]
    defs: dict[str, DefDecl]
    sentinels: dict[str, str] = field(default_factory=dict)

    def lookup(self, name: str) -> Expr | DefDecl:
        """Return what *name* declares, or raise if nothing does."""
        if name in self.unis:
            return self.unis[name]
        if name in self.defs:
            return self.defs[name]
        msg = f"unknown name: @{name}"
        raise HimarkScopeError(msg)


def _expr_refs(expr: Expr) -> Iterator[str]:
    """Yield every name an expression references, at any depth."""
    for unit in expr.units:
        yield from _unit_refs(unit)


def _unit_refs(unit: Unit) -> Iterator[str]:
    """Yield every name a unit references, through its base and its pipeline."""
    base = unit.base
    if isinstance(base, Ref):
        yield base.name
    elif isinstance(base, UniverseNode):
        for member in base.members:
            yield from _member_refs(member)
    for bracket in unit.pipelines:
        for item in bracket:
            yield item.lo


def _member_refs(member: Member) -> Iterator[str]:
    """Yield every name a member references, at any depth."""
    if isinstance(member, Subtract):
        for inner in member.universe.members:
            yield from _member_refs(inner)
    elif isinstance(member, Segments):
        for segment in member.segments:
            if isinstance(segment, Unit):
                yield from _unit_refs(segment)


def _body(declared: Expr | DefDecl) -> Expr:
    """The expression a declaration stands for."""
    return declared if isinstance(declared, Expr) else declared.expr


def _check_acyclic(env: Env) -> None:
    """Raise if any name reaches itself, directly or through other names."""
    graph = {
        name: {
            ref
            for ref in _expr_refs(_body(env.lookup(name)))
            if ref not in RESERVED and _known(env, ref)
        }
        for name in [*env.unis, *env.defs]
    }
    try:
        graphlib.TopologicalSorter(graph).prepare()
    except graphlib.CycleError as exc:
        cycle = " -> ".join(f"@{node}" for node in exc.args[1])
        msg = f"cyclic name: {cycle}"
        raise HimarkScopeError(msg) from exc


def _known(env: Env, name: str) -> bool:
    """Whether *name* is declared; unknown names are reported where they are used."""
    return name in env.unis or name in env.defs


def collect(script: ScriptNode) -> Env:
    """Collect a script's declarations into an :class:`Env`, checking acyclicity.

    Raises:
        HimarkScopeError: a name is reserved, declared twice, or cyclic.
    """
    env = Env({}, {})
    for line in script.lines:
        if isinstance(line, Statement | IterStatement):
            continue
        if line.name in RESERVED:
            msg = f"reserved name: @{line.name} is a register"
            raise HimarkScopeError(msg)
        if _known(env, line.name):
            msg = f"duplicate name: {line.name} is already declared"
            raise HimarkScopeError(msg)
        if isinstance(line, UniDecl):
            env.unis[line.name] = line.expr
        elif isinstance(line, SentinelDecl):
            face = _allocate(env)
            env.sentinels[line.name] = face
            env.unis[line.name] = Expr((Unit(UniverseNode((Segments((Face(face),)),))),))
        else:
            env.defs[line.name] = line
    _check_acyclic(env)
    return env


def _allocate(env: Env) -> str:
    """The next sentinel's face: one noncharacter, in declaration order.

    Raises:
        HimarkScopeError: the noncharacter block is exhausted.
    """
    index = len(env.sentinels)
    if index == SENTINEL_LIMIT:
        msg = f"sentinel space exhausted: at most {SENTINEL_LIMIT} per script"
        raise HimarkScopeError(msg)
    return chr(SENTINEL_BASE + index)


def statements(script: ScriptNode) -> tuple[Statement | IterStatement, ...]:
    """The script's statements, in source order; declarations are not statements."""
    return tuple(line for line in script.lines if isinstance(line, Statement | IterStatement))


def merge(base: Env, extra: Env) -> Env:
    """Layer *extra*'s declarations over *base*, so a script may shadow nothing.

    Raises:
        HimarkScopeError: *extra* redeclares a name *base* already holds.
    """
    for name in [*extra.unis, *extra.defs]:
        if _known(base, name):
            msg = f"duplicate name: {name} is already declared"
            raise HimarkScopeError(msg)
    # Allocation is per-collect; the std seeds no sentinels, so merged faces
    # never alias.
    return Env(
        {**base.unis, **extra.unis},
        {**base.defs, **extra.defs},
        {**base.sentinels, **extra.sentinels},
    )


def _binding(item: PipeItem) -> Binding:
    """Read one pipeline item as an argument; a lone item may still bind a pair."""
    return Binding(item.lo, item.hi)


def bind(items: tuple[PipeItem, ...], env: Env) -> tuple[Stage, ...]:
    """Split a flat pipeline item list into stages, by each definition's arity.

    Raises:
        HimarkScopeError: an item names no definition, or arguments run out.
    """
    stages: list[Stage] = []
    index = 0
    while index < len(items):
        name = items[index].lo
        definition = env.defs.get(name)
        if definition is None:
            msg = f"pipeline stage names no definition: {name}"
            raise HimarkScopeError(msg)
        arity = len(definition.params)
        arguments = items[index + 1 : index + 1 + arity]
        if len(arguments) < arity:
            msg = f"{name} takes {arity} argument(s), got {len(arguments)}"
            raise HimarkScopeError(msg)
        stages.append(Stage(definition, tuple(_binding(item) for item in arguments)))
        index += 1 + arity
    return tuple(stages)


def canonicalize(spelling: str, zero: str) -> str:
    """Strip leading zero digits in the head radix, keeping the last one.

    ``aa`` binds as ``a`` when the head's zero entry is ``a``: leading zero
    digits carry no value, so the canonical numeral is what a parameter binds.
    """
    if not zero:
        return spelling
    while spelling.startswith(zero) and len(spelling) > len(zero):
        spelling = spelling[len(zero) :]
    return spelling
