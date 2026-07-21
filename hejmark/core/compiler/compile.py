"""Compilation: lower a resolved script to the boundary's :class:`Program`.

The compiler's last phase. Everything language-shaped is settled here -- the
strictly-left rule, template lowering, the measure's expansion, the sentinel
table -- so what leaves is pure data plus one callback: the
:class:`~hejmark.core.compiler.late.SlotTable`'s resolver, which is the only
live object a back-referencing program still needs from this side.
"""

from __future__ import annotations

from hejmark.core.compiler.ast import (
    Expr,
    Interp,
    IterStatement,
    Ref,
    RefInterp,
    ScriptNode,
    Statement,
    Template,
    Unit,
)
from hejmark.core.compiler.expand import Ctx, expand
from hejmark.core.compiler.late import SlotTable, reads
from hejmark.core.compiler.ports import ToAst
from hejmark.core.compiler.resolve import Env, collect, merge, statements
from hejmark.core.compiler.std import std_env
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
    LateResolver,
    Program,
    QueryFactor,
    Sentinel,
    SentinelPart,
    TemplatePart,
    TextPart,
)


def script(to_ast: ToAst, source: str) -> tuple[ScriptNode, Env]:
    """Parse *source* and resolve its declarations over the seeded std."""
    node = to_ast(source)
    return node, merge(std_env(to_ast), collect(node))


def compile_query(expr: Expr, env: Env, table: SlotTable, source: str = "") -> CompiledQuery:
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
            factors.append(expand(Expr((unit,)), Ctx(env))[0])
    return CompiledQuery(source, tuple(factors))


def compile_script(node: ScriptNode, env: Env) -> tuple[Program, LateResolver]:
    """Lower a whole script: one program, one slot table, one resolver.

    Raises:
        HimarkScopeError: a query or measure in the script refuses to lower.
    """
    table = SlotTable()
    lines: list[CompiledLine] = []
    for stmt in statements(node):
        if isinstance(stmt, IterStatement):
            lines.append(_contract(stmt, env, table))
        else:
            lines.append(_statement(stmt, env, table))
    sentinels = tuple(Sentinel(name, face) for name, face in env.sentinels.items())
    return Program(tuple(lines), sentinels), table.resolve


def compile_single(node: ScriptNode, env: Env, source: str) -> tuple[CompiledQuery, LateResolver]:
    """Lower the one query expression a query-level script holds.

    Raises:
        HimarkScopeError: *node* is not a single query expression.
    """
    table = SlotTable()
    return compile_query(_single_expr(node), env, table, source), table.resolve


def lower(to_ast: ToAst, source: str) -> tuple[UniverseNode, ...]:
    """Parse *source* and expand each factor to its floor AST, before denotation.

    The fully-standalone hand-off (the Rust ``find`` binary reads its encoding
    back): expansion has rewritten the surface into the six constructors, and
    the floor AST serializes. A back-referencing factor rides a query as a late
    slot and cannot be lowered ahead of a binding, so it is refused rather than
    emitted.

    Raises:
        HimarkScopeError: *source* is not a single query expression, or a
            factor reads one to its left.
    """
    node, env = script(to_ast, source)
    expr = _single_expr(node)
    forms: list[UniverseNode] = []
    for unit in expr.units:
        if reads(unit):
            msg = "a back-referencing factor cannot be lowered to JSON"
            raise HimarkScopeError(msg)
        forms.append(expand(Expr((unit,)), Ctx(env))[0])
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


def _statement(stmt: Statement, env: Env, table: SlotTable) -> CompiledStatement:
    """Lower one statement: each step a compiled query or a lowered template."""
    steps: list[CompiledStep] = []
    for step in stmt.steps:
        if isinstance(step, Expr):
            steps.append(compile_query(step, env, table))
        else:
            steps.append(_template(step))
    return CompiledStatement(tuple(steps))


def _contract(stmt: IterStatement, env: Env, table: SlotTable) -> CompiledIter:
    """Lower a contracting statement; the measure expands here, not per pass.

    Raises:
        HimarkScopeError: the measure names nothing the environment declares.
    """
    measure = expand(Expr((Unit(Ref(stmt.measure)),)), Ctx(env))[0]
    return CompiledIter(
        compile_query(stmt.query, env, table),
        stmt.measure,
        measure,
        _template(stmt.template),
    )


def _template(template: Template) -> CompiledTemplate:
    """Lower a template part by part: text, capture reads, sentinel splices."""
    parts: list[TemplatePart] = []
    for part in template.parts:
        if isinstance(part, Interp):
            parts.append(CapturePart(part.capture))
        elif isinstance(part, RefInterp):
            parts.append(SentinelPart(part.name))
        else:
            parts.append(TextPart(part.text))
    return CompiledTemplate(tuple(parts))
