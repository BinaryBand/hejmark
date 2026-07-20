"""Tests for the cli layer."""

from __future__ import annotations

from typing import TYPE_CHECKING
from unittest.mock import patch

from typer.testing import CliRunner

from hejmark.adapters.antlr import AntlrToolNotFoundError
from hejmark.adapters.parser import GeneratedParserMissingError
from hejmark.cli.main import app

if TYPE_CHECKING:
    from pathlib import Path

runner = CliRunner()


def test_status_runs() -> None:
    # Multiple commands now exist, so `status` must be invoked by name -- a
    # bare `[]` shows help instead of running it.
    result = runner.invoke(app, ["status"])
    assert result.exit_code == 0


def test_gen_parser_runs_generator(tmp_path: Path) -> None:
    lexer = tmp_path / "GrammarLexer.g4"
    parser = tmp_path / "GrammarParser.g4"
    output_dir = tmp_path / "out"
    with patch("hejmark.cli.main.AntlrGenerator") as generator_cls:
        result = runner.invoke(
            app,
            [
                "gen-parser",
                "--grammar",
                str(lexer),
                "--grammar",
                str(parser),
                "--output-dir",
                str(output_dir),
            ],
        )
    assert result.exit_code == 0
    generator_cls.return_value.generate.assert_called_once_with(
        [lexer, parser], output_dir, language="Python3"
    )


def test_gen_parser_reports_missing_tool(tmp_path: Path) -> None:
    with patch("hejmark.cli.main.AntlrGenerator") as generator_cls:
        generator_cls.return_value.generate.side_effect = AntlrToolNotFoundError("no antlr4")
        result = runner.invoke(app, ["gen-parser", "--grammar", str(tmp_path / "g.g4")])
    assert result.exit_code == 1
    assert "no antlr4" in result.output


def test_parse_file_prints_tree_to_console_by_default(tmp_path: Path) -> None:
    source = tmp_path / "example.hmk"
    source.write_text("{a,b,c}")
    with patch("hejmark.cli.main.AntlrParser") as parser_cls:
        parser_cls.return_value.parse.return_value = []
        parser_cls.return_value.parse_tree.return_value = "(query (set a b c))"
        result = runner.invoke(app, ["parse-file", str(source)])
    assert result.exit_code == 0
    assert "(query (set a b c))" in result.output
    parser_cls.return_value.parse.assert_called_once_with("{a,b,c}")
    parser_cls.return_value.parse_tree.assert_called_once_with("{a,b,c}")


def test_parse_file_writes_tree_to_out_file(tmp_path: Path) -> None:
    source = tmp_path / "example.hmk"
    source.write_text("{a,b,c}")
    out = tmp_path / "example.tree"
    with patch("hejmark.cli.main.AntlrParser") as parser_cls:
        parser_cls.return_value.parse.return_value = []
        parser_cls.return_value.parse_tree.return_value = "(query (set a b c))"
        result = runner.invoke(app, ["parse-file", str(source), "--out", str(out)])
    assert result.exit_code == 0
    assert out.read_text() == "(query (set a b c))"
    assert "(query (set a b c))" not in result.output
    assert "OK" in result.output


def test_parse_file_reports_syntax_errors(tmp_path: Path) -> None:
    source = tmp_path / "example.hmk"
    source.write_text("{a")
    with patch("hejmark.cli.main.AntlrParser") as parser_cls:
        parser_cls.return_value.parse.return_value = ["1:2 missing '}'"]
        result = runner.invoke(app, ["parse-file", str(source)])
    assert result.exit_code == 1
    assert "missing '}'" in result.output


def test_parse_file_reports_missing_generated_parser(tmp_path: Path) -> None:
    source = tmp_path / "example.hmk"
    source.write_text("{a,b,c}")
    with patch("hejmark.cli.main.AntlrParser") as parser_cls:
        parser_cls.return_value.parse.side_effect = GeneratedParserMissingError("run gen-parser")
        result = runner.invoke(app, ["parse-file", str(source)])
    assert result.exit_code == 1
    assert "run gen-parser" in result.output


def test_find_reports_matches_and_a_count(tmp_path: Path) -> None:
    query = tmp_path / "q.hmk"
    target = tmp_path / "t.txt"
    query.write_text("{a}\n")  # a trailing newline is stripped before parsing
    target.write_text("banana")
    result = runner.invoke(app, ["find", str(query), str(target)])
    assert result.exit_code == 0
    assert "1:2\t'a'" in result.stdout
    assert "3 match(es)." in result.stdout


def test_find_reports_no_matches(tmp_path: Path) -> None:
    query = tmp_path / "q.hmk"
    target = tmp_path / "t.txt"
    query.write_text("{z}")
    target.write_text("banana")
    result = runner.invoke(app, ["find", str(query), str(target)])
    assert result.exit_code == 0
    assert "0 match(es)." in result.stdout


def test_find_rejects_an_invalid_query(tmp_path: Path) -> None:
    query = tmp_path / "q.hmk"
    target = tmp_path / "t.txt"
    query.write_text("{a")
    target.write_text("banana")
    result = runner.invoke(app, ["find", str(query), str(target)])
    # A usage error, the way click reports a bad argument.
    assert result.exit_code == 2


def test_run_splices_the_document(tmp_path: Path) -> None:
    script = tmp_path / "s.hmk"
    target = tmp_path / "t.txt"
    script.write_text('uni synonym = {{cat,feline}}\n{@synonym} => "{{$0}}"\n')
    target.write_text("my feline friend")
    result = runner.invoke(app, ["run", str(script), str(target)])
    assert result.exit_code == 0
    assert result.stdout == "my cat friend"


def test_run_rejects_an_unknown_name(tmp_path: Path) -> None:
    script = tmp_path / "s.hmk"
    target = tmp_path / "t.txt"
    script.write_text("{@nope}")
    target.write_text("text")
    result = runner.invoke(app, ["run", str(script), str(target)])
    assert result.exit_code == 2
