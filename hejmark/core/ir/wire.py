"""The Program wire format: a compiled script as versioned, tagged JSON.

This is the non-normative reference for the compiler -> engine payload (the
foundation docs deliberately stop at the language; the payload is a host
concern). A program serializes as::

    {"format": "hejmark-program", "version": 3,
     "sentinels": [{"name": "end", "face": [64976]}],
     "statements": [
       {"kind": "statement", "steps": [
         {"kind": "query", "source": "{a}{$1}", "factors": [
            {"kind": "universe", "universe": {"members": [...]}},
            {"kind": "slot", "slot": 0, "needs": [1]}]},
         {"kind": "template", "parts": [
            {"kind": "text", "text": [99, 97, 116]},
            {"kind": "capture", "capture": "$1"},
            {"kind": "sentinel", "name": "end"}]}]},
       {"kind": "iter", "query": {...}, "template": {...}}]}

Universes are :mod:`~hejmark.core.ir.codec`'s shapes. Faces, template text and
sentinel faces are code-point arrays (the lone-surrogate rule); names, capture
spellings and the diagnostic ``source`` stay JSON strings. A decoded program
holding a slot executes only against a resolver honoring its slot ids; a
slot-free program is fully standalone.
"""

from __future__ import annotations

from typing import assert_never

from hejmark.core.ir.codec import (
    decode_text,
    decode_universe,
    encode_universe,
    require_array,
    require_field,
)
from hejmark.core.ir.errors import HimarkPayloadError
from hejmark.core.ir.program import (
    CapturePart,
    CompiledIter,
    CompiledLine,
    CompiledQuery,
    CompiledStatement,
    CompiledStep,
    CompiledTemplate,
    EagerFactor,
    LateSlot,
    Program,
    QueryFactor,
    Sentinel,
    SentinelPart,
    TemplatePart,
    TextPart,
)

FORMAT = "hejmark-program"
VERSION = 3


def encode_program(program: Program) -> dict[str, object]:
    """Encode a compiled script as the versioned wire object."""
    return {
        "format": FORMAT,
        "version": VERSION,
        "sentinels": [
            {"name": sentinel.name, "face": _points(sentinel.face)}
            for sentinel in program.sentinels
        ],
        "statements": [_encode_line(line) for line in program.statements],
    }


def decode_program(obj: object) -> Program:
    """Decode the versioned wire object back to a :class:`Program`.

    Raises:
        HimarkPayloadError: the format tag, version, or any node is malformed.
    """
    if require_field(obj, "format", "program") != FORMAT:
        msg = f"malformed program: format is not {FORMAT!r}"
        raise HimarkPayloadError(msg)
    if require_field(obj, "version", "program") != VERSION:
        msg = f"malformed program: version is not {VERSION}"
        raise HimarkPayloadError(msg)
    sentinels = require_array(require_field(obj, "sentinels", "program"), "sentinels")
    statements = require_array(require_field(obj, "statements", "program"), "statements")
    return Program(
        tuple(_decode_line(line) for line in statements),
        tuple(_decode_sentinel(item) for item in sentinels),
    )


def _encode_line(line: CompiledLine) -> dict[str, object]:
    """Encode one statement, tagged by shape."""
    if isinstance(line, CompiledStatement):
        return {"kind": "statement", "steps": [_encode_step(step) for step in line.steps]}
    return {
        "kind": "iter",
        "query": _encode_step(line.query),
        "template": _encode_step(line.template),
    }


def _decode_line(obj: object) -> CompiledLine:
    """Decode one tagged statement."""
    kind = require_field(obj, "kind", "statement")
    line: CompiledLine
    if kind == "statement":
        steps = require_array(require_field(obj, "steps", "statement"), "steps")
        line = CompiledStatement(tuple(_decode_step(step) for step in steps))
    elif kind == "iter":
        line = CompiledIter(
            _decode_query(require_field(obj, "query", "iter")),
            _decode_template(require_field(obj, "template", "iter")),
        )
    else:
        msg = f"malformed statement: unknown kind {kind!r}"
        raise HimarkPayloadError(msg)
    return line


def _encode_step(step: CompiledStep) -> dict[str, object]:
    """Encode one step: a query or a template, tagged."""
    if isinstance(step, CompiledQuery):
        return {
            "kind": "query",
            "source": step.source,
            "factors": [_encode_factor(factor) for factor in step.factors],
        }
    return {"kind": "template", "parts": [_encode_part(part) for part in step.parts]}


def _decode_step(obj: object) -> CompiledStep:
    """Decode one tagged step."""
    kind = require_field(obj, "kind", "step")
    if kind == "query":
        return _decode_query(obj)
    if kind == "template":
        return _decode_template(obj)
    msg = f"malformed step: unknown kind {kind!r}"
    raise HimarkPayloadError(msg)


def _decode_query(obj: object) -> CompiledQuery:
    """Decode a query step, requiring its tag."""
    if require_field(obj, "kind", "query") != "query":
        msg = "malformed query: kind is not 'query'"
        raise HimarkPayloadError(msg)
    factors = require_array(require_field(obj, "factors", "query"), "factors")
    return CompiledQuery(
        _str(require_field(obj, "source", "query"), "source"),
        tuple(_decode_factor(factor) for factor in factors),
    )


def _decode_template(obj: object) -> CompiledTemplate:
    """Decode a template step, requiring its tag."""
    if require_field(obj, "kind", "template") != "template":
        msg = "malformed template: kind is not 'template'"
        raise HimarkPayloadError(msg)
    parts = require_array(require_field(obj, "parts", "template"), "parts")
    return CompiledTemplate(tuple(_decode_part(part) for part in parts))


def _encode_factor(factor: QueryFactor) -> dict[str, object]:
    """Encode one query factor: an eager universe, or a late slot."""
    if isinstance(factor, LateSlot):
        return {
            "kind": "slot",
            "slot": factor.slot,
            "needs": list(factor.needs),
        }
    return {
        "kind": "universe",
        "universe": encode_universe(factor.node),
    }


def _decode_factor(obj: object) -> QueryFactor:
    """Decode one tagged query factor."""
    kind = require_field(obj, "kind", "factor")
    factor: QueryFactor
    if kind == "universe":
        factor = EagerFactor(decode_universe(require_field(obj, "universe", "factor")))
    elif kind == "slot":
        needs = require_array(require_field(obj, "needs", "slot"), "needs")
        factor = LateSlot(
            _int(require_field(obj, "slot", "slot"), "slot"),
            tuple(_int(item, "needs") for item in needs),
        )
    else:
        msg = f"malformed factor: unknown kind {kind!r}"
        raise HimarkPayloadError(msg)
    return factor


def _encode_part(part: TemplatePart) -> dict[str, object]:
    """Encode one template part, tagged by shape."""
    payload: dict[str, object]
    if isinstance(part, TextPart):
        payload = {"kind": "text", "text": _points(part.text)}
    elif isinstance(part, CapturePart):
        payload = {"kind": "capture", "capture": part.capture}
    elif isinstance(part, SentinelPart):
        payload = {"kind": "sentinel", "name": part.name}
    else:
        assert_never(part)
    return payload


def _decode_part(obj: object) -> TemplatePart:
    """Decode one tagged template part."""
    kind = require_field(obj, "kind", "part")
    part: TemplatePart
    if kind == "text":
        part = TextPart(decode_text(require_field(obj, "text", "text")))
    elif kind == "capture":
        part = CapturePart(_str(require_field(obj, "capture", "capture"), "capture"))
    elif kind == "sentinel":
        part = SentinelPart(_str(require_field(obj, "name", "sentinel"), "name"))
    else:
        msg = f"malformed part: unknown kind {kind!r}"
        raise HimarkPayloadError(msg)
    return part


def _decode_sentinel(obj: object) -> Sentinel:
    """Decode one sentinel allocation."""
    return Sentinel(
        _str(require_field(obj, "name", "sentinel"), "name"),
        decode_text(require_field(obj, "face", "sentinel")),
    )


def _points(text: str) -> list[int]:
    """A spelling as its code points."""
    return [ord(character) for character in text]


def _str(value: object, what: str) -> str:
    """Require a JSON string."""
    if not isinstance(value, str):
        msg = f"malformed {what}: not a string"
        raise HimarkPayloadError(msg)
    return value


def _int(value: object, what: str) -> int:
    """Require an integer."""
    if not isinstance(value, int) or isinstance(value, bool):
        msg = f"malformed {what}: not an integer"
        raise HimarkPayloadError(msg)
    return value
