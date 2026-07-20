"""Where a closure binds, and whether it settles.

Two structural questions about a brace expression, both answered by reading the
AST rather than by denoting anything:

``binds`` -- does a free ``&`` occur in these members? A subtraction's braces
never bind, so ``&`` inside one reads the *outer* binder; that asymmetry is the
whole content of :func:`free_amp`.

``settled`` -- is every free ``&`` guarded, so that each closure pass strictly
lengthens and membership settles at stage ``len(spelling) + 1``? A ``&`` alone
is unguarded (the pass can repeat itself); a ``&`` in a product is guarded when
some sibling factor cannot spell the empty face.

That last clause is the one thing here that is not purely syntactic, so it
arrives as a parameter: ``spells_empty`` decides whether a factor's face set
holds ``""``. Threading it in (rather than denoting a universe here) is what
keeps this module a leaf, and it states the real shape of the property --
settledness is syntactic *modulo* an emptiness oracle.
"""

from __future__ import annotations

from collections.abc import Callable

from hejmark.core.floor.syntax import Closure, Member, Product, Subtract, UniverseNode

# Decides whether a node's face set holds the empty spelling.
SpellsEmpty = Callable[[UniverseNode], bool]


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


def settled(node: UniverseNode, spells_empty: SpellsEmpty) -> bool:
    """Whether every free ``&`` is guarded, so membership settles by stage len + 1."""
    return all(_settled_member(member, spells_empty) for member in node.members)


def _settled_member(member: Member, spells_empty: SpellsEmpty) -> bool:
    """Whether this member's free ``&`` occurrences (if any) are guarded."""
    if isinstance(member, Closure):
        return False
    if isinstance(member, Product) and any(isinstance(f, Closure) for f in member.factors):
        return any(_guards(f, spells_empty) for f in member.factors if isinstance(f, UniverseNode))
    if isinstance(member, Subtract):
        return settled(member.universe, spells_empty)
    return True


def _guards(factor: UniverseNode, spells_empty: SpellsEmpty) -> bool:
    """Whether a factor guards its product: no empty face, so every pass lengthens."""
    return not spells_empty(factor)
