"""Tests for the cli.commands.gen_parser module."""

from __future__ import annotations

from Himark.cli.commands.gen_parser import gen_parser


def test_gen_parser_is_callable() -> None:
    """gen_parser should be a callable registered via @command."""
    # We can't actually run gen_parser (it needs antlr4 on PATH), but we
    # can verify it is the decorated function returned by @command.
    assert callable(gen_parser)
