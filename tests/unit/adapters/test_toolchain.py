"""Tests for the adapters layer: the developer build steps."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from hejmark.adapters.toolchain import Step, ToolchainBuilder, ToolchainError, repository_root


def _checkout(tmp_path: Path) -> Path:
    """A directory shaped like a hejmark checkout, minus everything in it."""
    (tmp_path / "pyproject.toml").write_text("")
    (tmp_path / "rust").mkdir()
    return tmp_path


def test_the_root_is_the_nearest_ancestor_holding_both_markers(tmp_path: Path) -> None:
    root = _checkout(tmp_path)
    nested = root / "gui" / "lib"
    nested.mkdir(parents=True)
    assert repository_root(nested) == root.resolve()


def test_outside_a_checkout_says_so_rather_than_guessing(tmp_path: Path) -> None:
    with pytest.raises(ToolchainError, match="not inside a hejmark checkout"):
        repository_root(tmp_path)


def test_the_steps_build_the_binaries_before_the_library(tmp_path: Path) -> None:
    """Debug binaries first (what a desktop run uses), then what the app loads."""
    steps = ToolchainBuilder().steps(tmp_path, host_only=False)
    assert [step.argv[0] for step in steps] == ["cargo", str(tmp_path / "gui/tool/build_engine.sh")]
    assert steps[0].cwd == tmp_path / "rust"
    assert "--host-only" not in steps[1].argv


def test_host_only_rides_through_to_the_engine_script(tmp_path: Path) -> None:
    """The flag is the difference between needing the Android NDK and not."""
    steps = ToolchainBuilder().steps(tmp_path, host_only=True)
    assert steps[1].argv[1:] == ("--host-only",)


def test_a_step_that_succeeds_returns_quietly(tmp_path: Path) -> None:
    ToolchainBuilder().run(Step("noop", (sys.executable, "-c", ""), tmp_path))


def test_a_failing_step_names_itself_and_carries_the_output(tmp_path: Path) -> None:
    step = Step("engine", (sys.executable, "-c", "raise SystemExit('boom')"), tmp_path)
    with pytest.raises(ToolchainError, match=r"engine.*exit 1"):
        ToolchainBuilder().run(step)


def test_a_missing_tool_is_a_sentence_rather_than_a_traceback(tmp_path: Path) -> None:
    step = Step("engine", (str(tmp_path / "absent.sh"),), tmp_path)
    with pytest.raises(ToolchainError, match="cannot run"):
        ToolchainBuilder().run(step)
