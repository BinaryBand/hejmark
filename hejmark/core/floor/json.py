"""Encode the floor AST to portable JSON for the Rust port to denote.

This package parses and expands Himark; the Rust port denotes and matches. The
two meet at the floor AST, which serializes here as a tagged JSON tree and is
read back by the Rust ``floor::json`` module. Spellings are encoded as
code-point arrays rather than JSON strings, so lone surrogates survive intact.

Pure: it walks :mod:`hejmark.core.floor.syntax` nodes and touches nothing above
the floor, which is why it may live in the floor layer at all.
"""

from __future__ import annotations

from collections.abc import Sequence

from hejmark.core.floor.syntax import (
    Closure,
    Face,
    Final,
    Fold,
    Member,
    Product,
    Range,
    Subtract,
    UniverseNode,
)


def encode_query(universes: Sequence[UniverseNode]) -> dict[str, object]:
    """Encode a query -- a product of universes -- as ``{"universes": [...]}``."""
    return {"universes": [encode_universe(node) for node in universes]}


def encode_universe(node: UniverseNode) -> dict[str, object]:
    """Encode a brace group as ``{"members": [...]}`` in declaration order."""
    return {"members": [encode_member(member) for member in node.members]}


def encode_member(member: Member) -> dict[str, object]:
    """Encode one member as a ``{"kind": ...}`` object, tagged by constructor."""
    payload: dict[str, object]
    match member:
        case Face(text):
            payload = {"kind": "face", "text": _code_points(text)}
        case Range(lo, hi):
            payload = {"kind": "range", "lo": ord(lo), "hi": ord(hi)}
        case Final(lo):
            payload = {"kind": "final", "lo": _code_points(lo)}
        case Fold(universe):
            payload = {"kind": "fold", "universe": encode_universe(universe)}
        case Subtract(universe):
            payload = {"kind": "subtract", "universe": encode_universe(universe)}
        case Product(factors):
            payload = {"kind": "product", "factors": [encode_factor(f) for f in factors]}
        case Closure():
            payload = {"kind": "closure"}
    return payload


def encode_factor(factor: UniverseNode | Closure) -> dict[str, object]:
    """Encode a product factor: a nested universe, or the closure token."""
    if isinstance(factor, Closure):
        return {"kind": "closure"}
    return {"kind": "universe", "universe": encode_universe(factor)}


def _code_points(text: str) -> list[int]:
    """A spelling as its code points."""
    return [ord(character) for character in text]
