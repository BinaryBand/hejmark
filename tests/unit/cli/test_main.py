"""Tests for the cli layer."""

from __future__ import annotations

from typing import TYPE_CHECKING
from unittest.mock import patch

from typer.testing import CliRunner

from Himark.adapters.antlr import AntlrToolNotFoundError
from Himark.cli.main import app

if TYPE_CHECKING:
    from pathlib import Path

runner = CliRunner()


def test_status_runs() -> None:
    # Multiple commands now exist, so `status` must be invoked by name -- a
    # bare `[]` shows help instead of running it.
    result = runner.invoke(app, ["status"])
    assert result.exit_code == 0


def test_gen_parser_runs_generator(tmp_path: Path) -> None:
    grammar = tmp_path / "Grammar.g4"
    output_dir = tmp_path / "out"
    with patch("Himark.cli.main.AntlrGenerator") as generator_cls:
        result = runner.invoke(
            app,
            ["gen-parser", "--grammar", str(grammar), "--output-dir", str(output_dir)],
        )
    assert result.exit_code == 0
    generator_cls.return_value.generate.assert_called_once_with(
        grammar, output_dir, language="Python3"
    )


def test_gen_parser_reports_missing_tool(tmp_path: Path) -> None:
    with patch("Himark.cli.main.AntlrGenerator") as generator_cls:
        generator_cls.return_value.generate.side_effect = AntlrToolNotFoundError("no antlr4")
        result = runner.invoke(app, ["gen-parser", "--grammar", str(tmp_path / "g.g4")])
    assert result.exit_code == 1
    assert "no antlr4" in result.output
