"""Tests for the cli layer."""

from __future__ import annotations

import sys
from unittest.mock import MagicMock, patch

from typer.testing import CliRunner

from Himark.cli.main import _main_callback, app

runner = CliRunner()


def test_help_shows_commands() -> None:
    """--help must still list registered commands."""
    result = runner.invoke(app, ["--help"])
    assert result.exit_code == 0
    assert "gen-parser" in result.output
    assert "Himark" in result.output


def test_gen_parser_is_callable_by_name() -> None:
    """Commands registered via @command are callable by name."""
    result = runner.invoke(app, ["gen-parser", "--help"])
    assert result.exit_code == 0
    assert "Regenerate the ANTLR" in result.output


def test_no_args_non_tty_shows_error() -> None:
    """Without a tty the app must fail with a UsageError, not hang on input."""
    result = runner.invoke(app, [])
    # CliRunner doesn't provide a tty, so stdin.isatty() is False.
    # The callback raises click.UsageError which Typer surfaces as exit 2.
    assert result.exit_code != 0
    assert "No command specified" in result.output or "Usage" in result.output


def test_picker_dispatches_command() -> None:
    """The interactive picker should dispatch the selected command.

    The CliRunner replaces stdin/stdout and does not provide a tty, so we
    test the callback logic at a lower level: mock ``sys.stdin.isatty``,
    call the callback with a mock ``Context``, and verify the correct
    subcommand is invoked.
    """
    mock_ctx = MagicMock()
    mock_ctx.invoked_subcommand = None
    mock_ctx.command.list_commands.return_value = ["gen-parser"]
    mock_ctx.command.get_command.return_value = MagicMock(
        get_short_help_str=MagicMock(return_value="Regenerate the ANTLR parser"),
    )

    with (
        patch.object(sys.stdin, "isatty", return_value=True),
        patch("builtins.input", return_value="1"),
    ):
        _main_callback(mock_ctx)

    # The callback should have invoked gen-parser via ctx.invoke.
    mock_ctx.invoke.assert_called_once()
