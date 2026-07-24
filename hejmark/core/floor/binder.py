"""Where a closure binds.

``binds`` -- does a free ``&`` occur in these members? A subtraction's braces
never bind, so ``&`` inside one reads the *outer* binder; that asymmetry is the
whole content of :func:`free_amp`. Both answer by reading the AST rather than by
denoting anything, which keeps this module a leaf.
"""

from __future__ import annotations

from hejmark.core.floor.syntax import Closure, Member, Product, Subtract, UniverseNode


def binds(node: UniverseNode) -> bool:
    """Whether this brace expression is a closure binder: a free ``&`` in its members."""
    return any(free_amp(member) for member in node.members)


def free_amp(member: Member) -> bool:
    """Whether a free ``&`` occurs in this member (subtraction braces never bind)."""
    if isinstance(member, Closure):
        return True
    if isinstance(member, Product):
        return any(isinstance(factor, Closure) for factor in member.factors)
    if isinstance(member, Subtract):
        return binds(member.universe)
    return False
