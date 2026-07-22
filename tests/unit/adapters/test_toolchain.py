"""Tests for the adapters layer: locating the checkout a build step runs against."""

from __future__ import annotations

from pathlib import Path

import pytest

from hejmark.adapters.toolchain import ToolchainError, repository_root


def _checkout(tmp_path: Path) -> Path:
    """A directory shaped like a hejmark checkout, minus everything in it."""
    (tmp_path / "pyproject.toml").write_text("")
    return tmp_path


def test_the_root_is_the_nearest_ancestor_holding_pyproject(tmp_path: Path) -> None:
    root = _checkout(tmp_path)
    nested = root / "hejmark" / "core"
    nested.mkdir(parents=True)
    assert repository_root(nested) == root.resolve()


def test_outside_a_checkout_says_so_rather_than_guessing(tmp_path: Path) -> None:
    with pytest.raises(ToolchainError, match="not inside a hejmark checkout"):
        repository_root(tmp_path)
