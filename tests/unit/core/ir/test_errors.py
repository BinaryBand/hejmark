"""The boundary's exceptions are plain ValueErrors, catchable without imports."""

from __future__ import annotations

from hejmark.core.ir.errors import (
    CATEGORIES,
    HimarkPayloadError,
    HimarkScopeError,
    HimarkSentinelError,
)


def test_scope_error_is_a_value_error() -> None:
    """Callers may catch a refused scope as a plain ValueError."""
    assert issubclass(HimarkScopeError, ValueError)


def test_payload_error_is_a_value_error() -> None:
    """A payload that does not decode refuses the same way."""
    assert issubclass(HimarkPayloadError, ValueError)


def test_the_two_refusals_are_distinct() -> None:
    """A malformed payload is not a refused scope; neither catches the other."""
    assert not issubclass(HimarkPayloadError, HimarkScopeError)
    assert not issubclass(HimarkScopeError, HimarkPayloadError)


def test_every_refusal_has_a_wire_name() -> None:
    """A wire carries a name, so every refusal that can cross must have one."""
    assert set(CATEGORIES.values()) == {
        HimarkPayloadError,
        HimarkScopeError,
        HimarkSentinelError,
    }


def test_the_categories_are_the_names_the_protocol_states() -> None:
    """docs/protocol.md's error table, as data -- neither side restates it."""
    assert sorted(CATEGORIES) == ["payload", "scope", "sentinel"]
