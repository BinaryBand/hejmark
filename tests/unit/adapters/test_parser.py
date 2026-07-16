"""Tests for the antlr_parser adapter."""

from __future__ import annotations

import shutil
import sys
from collections.abc import Iterator
from pathlib import Path
from unittest.mock import patch

import pytest

from Himark.adapters.antlr import AntlrGenerator
from Himark.adapters.parser import AntlrParser, GeneratedParserMissingError

ROOT = Path(__file__).resolve().parents[3]
GRAMMAR = ROOT / "static" / "grammar" / "Himark.g4"
GEN_DIR = ROOT / "Himark" / "adapters" / "_gen"


@pytest.fixture(scope="module")
def _generated() -> Iterator[None]:
    """Generate the real `Himark.adapters._gen` package for this module's tests.

    `_gen` is a gitignored build artifact (see `AntlrGenerator`); `AntlrParser`
    imports it by its real package path, so exercising it for real means
    generating into that real location rather than mocking. Leaves an
    already-generated `_gen` alone (a developer may have one from `gen-parser`)
    and only tears down what this fixture created.
    """
    already_present = GEN_DIR.exists()
    if not already_present:
        AntlrGenerator().generate(GRAMMAR, GEN_DIR, language="Python3")
    try:
        yield
    finally:
        if not already_present:
            shutil.rmtree(GEN_DIR)
            for module in list(sys.modules):
                if module.startswith("Himark.adapters._gen"):
                    del sys.modules[module]


@pytest.mark.usefixtures("_generated")
def test_parse_returns_no_errors_for_valid_source() -> None:
    assert AntlrParser().parse("{a,b,c}") == []


@pytest.mark.usefixtures("_generated")
def test_parse_returns_errors_for_malformed_source() -> None:
    assert AntlrParser().parse("{a") != []


def test_parse_raises_when_generated_parser_missing() -> None:
    with (
        patch("importlib.import_module", side_effect=ModuleNotFoundError),
        pytest.raises(GeneratedParserMissingError),
    ):
        AntlrParser().parse("{a}")
