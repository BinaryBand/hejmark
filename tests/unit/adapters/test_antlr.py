"""Tests for the antlr adapter."""

from __future__ import annotations

import subprocess
from typing import TYPE_CHECKING
from unittest.mock import patch

import pytest

from Himark.adapters.antlr import AntlrGenerationError, AntlrGenerator, AntlrToolNotFoundError

if TYPE_CHECKING:
    from pathlib import Path


def test_generate_raises_when_tool_missing(tmp_path: Path) -> None:
    with patch("shutil.which", return_value=None), pytest.raises(AntlrToolNotFoundError):
        AntlrGenerator().generate(tmp_path / "Grammar.g4", tmp_path, language="Python3")


def test_generate_raises_on_nonzero_exit(tmp_path: Path) -> None:
    grammar = tmp_path / "Grammar.g4"
    output_dir = tmp_path / "out"
    failed = subprocess.CompletedProcess(args=[], returncode=1, stdout="", stderr="boom")
    with (
        patch("shutil.which", return_value="/usr/bin/antlr4"),
        patch("subprocess.run", return_value=failed) as run,
        pytest.raises(AntlrGenerationError),
    ):
        AntlrGenerator().generate(grammar, output_dir, language="Python3")
    assert run.called


def test_generate_invokes_antlr4_and_creates_output_dir(tmp_path: Path) -> None:
    grammar = tmp_path / "Grammar.g4"
    output_dir = tmp_path / "out" / "nested"
    ok = subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
    with (
        patch("shutil.which", return_value="/usr/bin/antlr4"),
        patch("subprocess.run", return_value=ok) as run,
    ):
        AntlrGenerator().generate(grammar, output_dir, language="Python3")
    assert output_dir.is_dir()
    args = run.call_args.args[0]
    assert args[0] == "/usr/bin/antlr4"
    assert "-Dlanguage=Python3" in args
    assert grammar.name in args
    assert str(output_dir.resolve()) in args
    assert run.call_args.kwargs["cwd"] == grammar.parent
