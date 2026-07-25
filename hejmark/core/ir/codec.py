"""Encode and decode the floor AST as portable JSON-shaped data.

The compiler lowers to floor nodes; an engine denotes them. They meet at this
codec: :func:`encode_universe` and :func:`decode_universe` are the wire
contract for any engine on the far side, so the encoder shapes must not drift.
Spellings are encoded as code-point arrays rather than JSON strings, so lone
surrogates survive intact.

Decoding refuses rather than guesses: an unknown tag, a missing field or a
code point past the plane space raises
:class:`~hejmark.core.ir.errors.HimarkPayloadError`.
"""

from __future__ import annotations

from collections.abc import Sequence
from typing import cast

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
from hejmark.core.ir.errors import HimarkPayloadError


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


def decode_universe(obj: object) -> UniverseNode:
    """Decode ``{"members": [...]}`` back to a brace group.

    Raises:
        HimarkPayloadError: the payload is not the encoder's shape.
    """
    items = require_array(require_field(obj, "members", "universe"), "members")
    return UniverseNode(tuple(decode_member(item) for item in items))


def decode_member(obj: object) -> Member:
    """Decode one tagged member back to its constructor.

    Raises:
        HimarkPayloadError: the tag is unknown or a field is malformed.
    """
    kind = require_field(obj, "kind", "member")
    member: Member
    if kind == "face":
        member = Face(decode_text(require_field(obj, "text", "face")))
    elif kind == "range":
        lo = require_field(obj, "lo", "range")
        hi = require_field(obj, "hi", "range")
        member = Range(_char(lo), _char(hi))
    elif kind == "final":
        member = Final(decode_text(require_field(obj, "lo", "final")))
    elif kind == "fold":
        member = Fold(decode_universe(require_field(obj, "universe", "fold")))
    elif kind == "subtract":
        member = Subtract(decode_universe(require_field(obj, "universe", "subtract")))
    elif kind == "product":
        items = require_array(require_field(obj, "factors", "product"), "factors")
        member = Product(tuple(decode_factor(item) for item in items))
    elif kind == "closure":
        member = Closure()
    else:
        msg = f"malformed member: unknown kind {kind!r}"
        raise HimarkPayloadError(msg)
    return member


def decode_factor(obj: object) -> UniverseNode | Closure:
    """Decode a product factor: a nested universe, or the closure token.

    Raises:
        HimarkPayloadError: the tag is neither.
    """
    kind = require_field(obj, "kind", "factor")
    if kind == "closure":
        return Closure()
    if kind == "universe":
        return decode_universe(require_field(obj, "universe", "factor"))
    msg = f"malformed factor: unknown kind {kind!r}"
    raise HimarkPayloadError(msg)


def require_field(obj: object, key: str, what: str) -> object:
    """Read *key* from a payload object, refusing anything else.

    Raises:
        HimarkPayloadError: *obj* is not an object or lacks *key*.
    """
    if not isinstance(obj, dict) or key not in obj:
        msg = f"malformed {what}: missing {key!r}"
        raise HimarkPayloadError(msg)
    return cast("dict[str, object]", obj)[key]


def require_array(value: object, what: str) -> list[object]:
    """Require an array.

    Raises:
        HimarkPayloadError: *value* is not one.
    """
    if not isinstance(value, list):
        msg = f"malformed {what}: not an array"
        raise HimarkPayloadError(msg)
    return cast("list[object]", value)


def decode_text(value: object) -> str:
    """Decode a code-point array back to a spelling.

    Raises:
        HimarkPayloadError: *value* is not an array of code points.
    """
    return "".join(_char(point) for point in require_array(value, "spelling"))


# The last code point: nothing past the seventeenth plane decodes.
_MAX_CODE_POINT = 0x10FFFF


def _char(value: object) -> str:
    """Decode one code point, refusing anything outside the plane space."""
    if not isinstance(value, int) or isinstance(value, bool) or not 0 <= value <= _MAX_CODE_POINT:
        msg = f"malformed spelling: {value!r} is no code point"
        raise HimarkPayloadError(msg)
    return chr(value)
