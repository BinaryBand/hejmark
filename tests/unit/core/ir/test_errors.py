"""The boundary's exceptions are plain ValueErrors, catchable without imports."""

from __future__ import annotations

from hejmark.core.ir.errors import HimarkPayloadError, HimarkScopeError


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
