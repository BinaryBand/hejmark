"""Compilation: lower a resolved script to the boundary's :class:`Program`.

The compiler's last phase. Everything language-shaped is settled here -- the
strictly-left rule, template lowering, and the sentinel table -- so what leaves
is pure data plus one callback: the
:class:`~hejmark.core.compiler.late.SlotTable`'s resolver, which is the only
live object a back-referencing program still needs from this side.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass

from hejmark.core.compiler.ast import (
    Expr,
    Interp,
    IterStatement,
    RefInterp,
    ScriptNode,
    Statement,
    Template,
)
from hejmark.core.compiler.expand import Ctx, expand
from hejmark.core.compiler.late import SlotTable, reads
from hejmark.core.compiler.ports import ToAst
from hejmark.core.compiler.prelude import prelude_env
from hejmark.core.compiler.resolve import Env, collect, merge, statements
from hejmark.core.floor.syntax import UniverseNode
from hejmark.core.ir.errors import HimarkScopeError
from hejmark.core.ir.program import (
    CapturePart,
    CompiledIter,
    CompiledLine,
    CompiledQuery,
    CompiledStatement,
    CompiledStep,
    CompiledTemplate,
    EagerFactor,
    LateResolver,
    Program,
    QueryFactor,
    TemplatePart,
    TextPart,
    ToFaces,
)


def script(to_ast: ToAst, source: str, prelude: str | None = None) -> tuple[ScriptNode, Env]:
    """Parse *source* and resolve its declarations over the prelude.

    *prelude* is the standard-library source to seed alongside ``char``, or
    ``None`` for ``char`` alone -- the library switched off.
    """
    node = to_ast(source)
    return node, merge(prelude_env(to_ast, prelude), collect(node))


def compile_query(
    faces: ToFaces, expr: Expr, env: Env, table: SlotTable, source: str = ""
) -> CompiledQuery:
    """Lower one query expression: eager units expand, back-references slot.

    A unit that back-references a factor to its left cannot expand yet; it
    enters *table* and crosses as its slot. A read of the reading factor
    itself, of one to its right, or past the written factors has nothing to
    bind and is refused.

    Raises:
        HimarkScopeError: a read is not strictly left of the factor reading it.
    """
    factors: list[QueryFactor] = []
    for index, unit in enumerate(expr.units):
        needs = reads(unit)
        past = [k for k in needs if k > index]
        if past:
            msg = f"${past[0]} reads factor {past[0]}, but only {index} factor(s) stand to its left"
            raise HimarkScopeError(msg)
        if needs:
            factors.append(table.add(unit, env, needs))
        else:
            factors.append(EagerFactor(expand(Expr((unit,)), Ctx(env, faces))[0]))
    return CompiledQuery(source, tuple(factors))


def compile_script(faces: ToFaces, node: ScriptNode, env: Env) -> tuple[Program, LateResolver]:
    """Lower a whole script: one program, one slot table, one resolver.

    Raises:
        HimarkScopeError: a query in the script refuses to lower.
    """
    table = SlotTable(faces)
    lines: list[CompiledLine] = []
    for stmt in statements(node):
        if isinstance(stmt, IterStatement):
            lines.append(_contract(faces, stmt, env, table))
        else:
            lines.append(_statement(faces, stmt, env, table))
    return Program(tuple(lines), tuple(env.sentinels.values())), table.resolve


def compile_single(
    faces: ToFaces, node: ScriptNode, env: Env, source: str
) -> tuple[CompiledQuery, LateResolver]:
    """Lower the one query expression a query-level script holds.

    Raises:
        HimarkScopeError: *node* is not a single query expression.
    """
    table = SlotTable(faces)
    return compile_query(faces, _single_expr(node), env, table, source), table.resolve


def lower(
    to_ast: ToAst, faces: ToFaces, source: str, prelude: str | None = None
) -> tuple[UniverseNode, ...]:
    """Parse *source* and expand each factor to its floor AST, before denotation.

    The fully-standalone hand-off: expansion has rewritten the surface into the
    five constructors, and the floor AST serializes for another engine to read
    back. A back-referencing factor rides a query as a late slot and cannot be
    lowered ahead of a binding, so it is refused rather than emitted.

    Raises:
        HimarkScopeError: *source* is not a single query expression, or a
            factor reads one to its left.
    """
    node, env = script(to_ast, source, prelude)
    return _lower_expr(faces, _single_expr(node), env)


@dataclass(frozen=True)
class Fragment:
    """One fragment's outcome: its lowered factors, or why there are none.

    Both fields empty is the third answer and not a failure: the fragment
    declared names and asked nothing.
    """

    forms: tuple[UniverseNode, ...] | None = None
    error: str | None = None


def lower_fragments(
    to_ast: ToAst, faces: ToFaces, sources: Sequence[str], prelude: str | None = None
) -> tuple[Fragment, ...]:
    """Lower each of *sources* to its floor AST under one shared environment.

    The fragment form of :func:`lower`. The sources are the lines of a single
    script that a host holds separately -- an editor's rule list, one rule per
    fragment -- so a name declared in one is in scope in the rest, exactly as
    it would be had they arrived as one file. Declarations are collected from
    every fragment's lines at once, which is what makes a duplicate name or a
    cycle across fragments the same diagnostic it is within one.

    A fragment holding no statement -- declarations alone, which :func:`lower`
    refuses -- lowers to an empty :class:`Fragment`: it contributes names, not
    a query. The result is positional either way, so a host pairs it back to
    the fragment it came from.

    A fragment that will not parse or will not lower carries its message and
    the rest still lower, because a host holding fragments separately is a host
    editing them separately: one being mid-keystroke is not a reason for the
    others to stop answering. Only a refusal *about the set* -- a name two
    fragments declare, a cycle between them -- raises, since there is then no
    environment to lower any of them under.

    Raises:
        HimarkScopeError: a name collides across fragments, or is cyclic.
    """
    parsed = [_parse_fragment(to_ast, source) for source in sources]
    lines = tuple(line for node in parsed if isinstance(node, ScriptNode) for line in node.lines)
    env = merge(prelude_env(to_ast, prelude), collect(ScriptNode(lines)))
    return tuple(_lower_fragment(faces, node, env) for node in parsed)


def _parse_fragment(to_ast: ToAst, source: str) -> ScriptNode | str:
    """Parse one fragment, or return the message saying why it would not."""
    try:
        return to_ast(source)
    except ValueError as exc:
        return str(exc)


def _lower_fragment(faces: ToFaces, node: ScriptNode | str, env: Env) -> Fragment:
    """Lower one parsed fragment's query, if it has one, under *env*."""
    if isinstance(node, str):
        return Fragment(error=node)
    if not statements(node):
        return Fragment()
    try:
        return Fragment(forms=_lower_expr(faces, _single_expr(node), env))
    except ValueError as exc:
        return Fragment(error=str(exc))


def _lower_expr(faces: ToFaces, expr: Expr, env: Env) -> tuple[UniverseNode, ...]:
    """Expand each of *expr*'s factors under *env*, before denotation.

    Raises:
        HimarkScopeError: a factor back-references one to its left.
    """
    forms: list[UniverseNode] = []
    for unit in expr.units:
        if reads(unit):
            msg = "a back-referencing factor cannot be lowered to JSON"
            raise HimarkScopeError(msg)
        forms.append(expand(Expr((unit,)), Ctx(env, faces))[0])
    return tuple(forms)


def _single_expr(node: ScriptNode) -> Expr:
    """The one query expression a query-level script holds.

    Raises:
        HimarkScopeError: *node* is not a single query expression.
    """
    found = statements(node)
    if len(found) != 1 or not isinstance(found[0], Statement):
        msg = "expected a single query expression"
        raise HimarkScopeError(msg)
    only = found[0]
    if len(only.steps) != 1 or not isinstance(only.steps[0], Expr):
        msg = "expected a single query expression"
        raise HimarkScopeError(msg)
    return only.steps[0]


def _statement(faces: ToFaces, stmt: Statement, env: Env, table: SlotTable) -> CompiledStatement:
    """Lower one statement: each step a compiled query or a lowered template."""
    steps: list[CompiledStep] = []
    for step in stmt.steps:
        if isinstance(step, Expr):
            steps.append(compile_query(faces, step, env, table))
        else:
            steps.append(_template(step, env))
    return CompiledStatement(tuple(steps))


def _contract(faces: ToFaces, stmt: IterStatement, env: Env, table: SlotTable) -> CompiledIter:
    """Lower a contracting statement: its query and template, iterated to a fixpoint."""
    return CompiledIter(
        compile_query(faces, stmt.query, env, table),
        _template(stmt.template, env),
    )


def _template(template: Template, env: Env) -> CompiledTemplate:
    """Lower a template part by part: text, capture reads, sentinel splices.

    A ``{{@name}}`` splice resolves to the face *here*: the compiler allocated
    it, so substituting it now leaves the engine a template of text and capture
    reads only, and turns an undeclared name into a compile-time refusal rather
    than one raised mid-render.

    Raises:
        HimarkScopeError: a splice names no declared sentinel.
    """
    parts: list[TemplatePart] = []
    for part in template.parts:
        if isinstance(part, Interp):
            parts.append(CapturePart(part.capture))
        elif isinstance(part, RefInterp):
            face = env.sentinels.get(part.name)
            if face is None:
                msg = f"{{{{@{part.name}}}}} reads no sentinel"
                raise HimarkScopeError(msg)
            parts.append(TextPart(face))
        else:
            parts.append(TextPart(part.text))
    return CompiledTemplate(tuple(parts))
