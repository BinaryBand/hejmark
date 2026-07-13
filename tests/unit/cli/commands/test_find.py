"""Tests for the cli.commands.find module."""

from __future__ import annotations

from typing import TYPE_CHECKING

from Himark.cli.commands.find import find

if TYPE_CHECKING:
    from pathlib import Path

    import pytest


def test_find_reports_matches(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    """find prints one line per match plus a count summary."""
    query_file = tmp_path / "q.hmk"
    query_file.write_text("{b}", encoding="utf-8")
    target_file = tmp_path / "target.txt"
    target_file.write_text("abcb", encoding="utf-8")

    find(query_file=query_file, target_file=target_file)

    out = capsys.readouterr().out
    assert "1:2\t'b'" in out
    assert "3:4\t'b'" in out
    assert "2 match(es)." in out


def test_find_strips_trailing_newline(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    """A .hmk file's trailing newline is stripped so the query still parses."""
    query_file = tmp_path / "q.hmk"
    query_file.write_text("{b}\n", encoding="utf-8")
    target_file = tmp_path / "target.txt"
    target_file.write_text("abc", encoding="utf-8")

    find(query_file=query_file, target_file=target_file)

    out = capsys.readouterr().out
    assert "1:2\t'b'" in out
    assert "1 match(es)." in out


def test_find_no_matches(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    """A query that matches nothing reports zero matches."""
    query_file = tmp_path / "q.hmk"
    query_file.write_text("{z}", encoding="utf-8")
    target_file = tmp_path / "target.txt"
    target_file.write_text("abc", encoding="utf-8")

    find(query_file=query_file, target_file=target_file)

    assert "0 match(es)." in capsys.readouterr().out
