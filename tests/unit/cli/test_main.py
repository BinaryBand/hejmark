"""Tests for the cli layer."""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import patch

import pytest
from typer.testing import CliRunner

from hejmark.adapters.antlr import AntlrToolNotFoundError
from hejmark.adapters.parser import GeneratedParserMissingError
from hejmark.cli.main import DEFAULT_GRAMMARS, DEFAULT_OUTPUT_DIR, app

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


def _checkout(root: Path) -> Path:
    """A directory `repository_root` will accept, with a nested directory to run from."""
    (root / "pyproject.toml").write_text("")
    (root / "nested").mkdir()
    return root / "nested"


def test_gen_parser_defaults_come_from_the_checkout_not_the_cwd(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Run from a nested directory, the omitted paths still name the checkout's own files.

    They are written relative to a checkout root, so taking them as-is meant
    looking for `nested/static/grammar` -- a directory that does not exist --
    and creating a second `_gen` under `nested/` on the way past.
    """
    monkeypatch.chdir(_checkout(tmp_path))
    with patch("hejmark.cli.main.AntlrGenerator") as generator_cls:
        result = runner.invoke(app, ["gen-parser"])
    assert result.exit_code == 0
    root = tmp_path.resolve()
    generator_cls.return_value.generate.assert_called_once_with(
        [root / one for one in DEFAULT_GRAMMARS], root / DEFAULT_OUTPUT_DIR, language="Python3"
    )


def test_gen_parser_says_so_when_a_default_has_no_checkout_to_come_from(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.chdir(tmp_path)
    with patch("hejmark.cli.main.AntlrGenerator") as generator_cls:
        result = runner.invoke(app, ["gen-parser"])
    assert result.exit_code == 1
    assert "not inside a hejmark checkout" in result.output
    generator_cls.return_value.generate.assert_not_called()


def test_gen_parser_keeps_explicit_paths_outside_a_checkout(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Given both, it needs no checkout: those paths are the caller's own."""
    monkeypatch.chdir(tmp_path)
    grammar, output_dir = tmp_path / "G.g4", tmp_path / "out"
    with patch("hejmark.cli.main.AntlrGenerator") as generator_cls:
        result = runner.invoke(
            app,
            ["gen-parser", "--grammar", str(grammar), "--output-dir", str(output_dir)],
        )
    assert result.exit_code == 0
    generator_cls.return_value.generate.assert_called_once_with(
        [grammar], output_dir, language="Python3"
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


def test_emit_json_prints_the_floor_ast(tmp_path: Path) -> None:
    query = tmp_path / "q.hmk"
    query.write_text("{a,b}\n")  # the trailing newline is stripped before parsing
    result = runner.invoke(app, ["emit-json", str(query)])
    assert result.exit_code == 0
    assert json.loads(result.stdout) == {
        "universes": [
            {"members": [{"kind": "face", "text": [97]}, {"kind": "face", "text": [98]}]},
        ],
    }


def test_emit_json_writes_to_an_out_file(tmp_path: Path) -> None:
    query = tmp_path / "q.hmk"
    out = tmp_path / "q.json"
    query.write_text("{a}")
    result = runner.invoke(app, ["emit-json", str(query), "--out", str(out)])
    assert result.exit_code == 0
    assert json.loads(out.read_text()) == {
        "universes": [{"members": [{"kind": "face", "text": [97]}]}],
    }
    assert "OK" in result.output


def test_emit_json_rejects_a_back_reference(tmp_path: Path) -> None:
    query = tmp_path / "q.hmk"
    query.write_text("{a,b}{$1}")
    result = runner.invoke(app, ["emit-json", str(query)])
    assert result.exit_code == 2  # a usage error, the way click reports a bad argument


def test_emit_fragments_lowers_each_file_under_the_shared_names(tmp_path: Path) -> None:
    """A declaring fragment emits null; the one using its name emits a query."""
    decl = tmp_path / "a.hmk"
    decl.write_text("uni d = {a,b}")
    query = tmp_path / "b.hmk"
    query.write_text("@d")
    result = runner.invoke(app, ["emit-fragments", str(decl), str(query)])
    assert result.exit_code == 0
    payload = json.loads(result.stdout)
    assert payload[0] is None
    assert payload[1] == {
        "universes": [
            {"members": [{"kind": "face", "text": [97]}, {"kind": "face", "text": [98]}]},
        ],
    }


def test_emit_fragments_isolates_a_broken_file_from_the_rest(tmp_path: Path) -> None:
    """A file that will not parse carries its message; its neighbour still compiles."""
    broken = tmp_path / "a.hmk"
    broken.write_text("{a")
    fine = tmp_path / "b.hmk"
    fine.write_text("{b}")
    result = runner.invoke(app, ["emit-fragments", str(broken), str(fine)])
    assert result.exit_code == 0
    payload = json.loads(result.stdout)
    assert "error" in payload[0]
    assert payload[1] == {"universes": [{"members": [{"kind": "face", "text": [98]}]}]}


def test_emit_fragments_reports_a_collision_between_two_files(tmp_path: Path) -> None:
    first = tmp_path / "a.hmk"
    first.write_text("uni d = {a}")
    second = tmp_path / "b.hmk"
    second.write_text("uni d = {b}")
    result = runner.invoke(app, ["emit-fragments", str(first), str(second)])
    assert result.exit_code == 2  # a usage error, as every compile refusal is here


def test_emit_program_prints_the_versioned_program(tmp_path: Path) -> None:
    script = tmp_path / "s.hmk"
    script.write_text('{a} => "x"\n')
    result = runner.invoke(app, ["emit-program", str(script)])
    assert result.exit_code == 0
    payload = json.loads(result.stdout)
    assert payload["format"] == "hejmark-program"
    assert payload["version"] == 2
    assert payload["sentinels"] == []
    assert [step["kind"] for step in payload["statements"][0]["steps"]] == ["query", "template"]


def test_emit_program_writes_to_an_out_file(tmp_path: Path) -> None:
    script = tmp_path / "s.hmk"
    out = tmp_path / "s.json"
    script.write_text('{a} => "x"')
    result = runner.invoke(app, ["emit-program", str(script), "--out", str(out)])
    assert result.exit_code == 0
    assert json.loads(out.read_text())["format"] == "hejmark-program"
    assert "OK" in result.output


def test_emit_program_keeps_a_back_reference_where_emit_json_refuses_it(tmp_path: Path) -> None:
    """A whole script has somewhere to put a late slot; a bare query does not."""
    script = tmp_path / "s.hmk"
    script.write_text('{a,b}{$1} => "x"')
    result = runner.invoke(app, ["emit-program", str(script)])
    assert result.exit_code == 0
    factors = json.loads(result.stdout)["statements"][0]["steps"][0]["factors"]
    assert factors[1]["kind"] == "slot"


def test_emit_program_rejects_an_unknown_name(tmp_path: Path) -> None:
    script = tmp_path / "s.hmk"
    script.write_text('{@nope} => "x"')
    result = runner.invoke(app, ["emit-program", str(script)])
    assert result.exit_code == 2  # a usage error, the way click reports a bad argument
