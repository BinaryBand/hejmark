"""Tests for the cli layer."""

from __future__ import annotations

from typer.testing import CliRunner

from Himark.cli.main import app

runner = CliRunner()


def test_no_args_shows_help() -> None:
    result = runner.invoke(app, [])
    assert result.exit_code != 0
    assert "gen-parser" in result.output


def test_gen_parser_is_callable_by_name() -> None:
    """The no-op callback keeps the app in named-subcommand mode."""
    result = runner.invoke(app, ["gen-parser", "--help"])
    assert result.exit_code == 0
    assert "Regenerate the ANTLR" in result.output
