"""Cross-language bridge: Python emits the floor AST as JSON, Rust denotes and matches it.

The two engines must agree on the same queries: Python's ``finditer`` spans have
to equal the spans the Rust ``find`` binary produces from the emitted JSON. This
exercises the whole hand-off -- ``hejmark.emit_json`` (parse + expand + encode)
into ``floor::json`` (decode) into ``denote`` and the matcher. Skips cleanly when
the Rust toolchain or tree is absent, the way tests/test_rust.py does.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

import hejmark

ROOT = Path(__file__).resolve().parents[2]
RUST = ROOT / "rust"

# Queries that lower to the floor without a back-reference, one per construct.
CASES = [
    ("{a}", "banana"),
    ("{a,b}", "abcab"),
    ("{a}{b}", "ababab"),
    ("{a..e}", "face the cave"),
    ("{{cat,feline}}", "a feline meets a cat"),
    ("{a..c, !{b}, b}", "abcbba"),
    ("{a, &{b}}", "abbb and ab"),
    ("{0..9}", "a1b22c333"),
]


@pytest.fixture(scope="module")
def rust_find() -> Path:
    """Build the Rust ``find`` binary once and return its path."""
    if not RUST.exists():
        pytest.skip("no rust/ tree")
    if shutil.which("cargo") is None:
        pytest.skip("cargo not on PATH")
    build = subprocess.run(
        ["cargo", "build", "--quiet", "--bin", "find"],
        cwd=RUST,
        capture_output=True,
        text=True,
        check=False,
    )
    if build.returncode != 0:
        pytest.fail(f"cargo build --bin find failed:\n{build.stdout}\n{build.stderr}")
    return RUST / "target" / "debug" / "find"


def _rust_spans(binary: Path, source: str, text: str, tmp_path: Path) -> list[tuple[int, int]]:
    """Emit *source* as JSON, run the Rust binary over *text*, parse its spans."""
    query_json = tmp_path / "query.json"
    target = tmp_path / "target.txt"
    query_json.write_text(hejmark.emit_json(source))
    target.write_text(text)
    result = subprocess.run(
        [str(binary), str(query_json), str(target)],
        capture_output=True,
        text=True,
        check=True,
    )
    spans: list[tuple[int, int]] = []
    for line in result.stdout.splitlines():
        start, end = line.split("\t")
        spans.append((int(start), int(end)))
    return spans


def _python_spans(source: str, text: str) -> list[tuple[int, int]]:
    return [found.span for found in hejmark.finditer(source, text)]


@pytest.mark.parametrize(("source", "text"), CASES)
def test_rust_matches_agree_with_python(
    rust_find: Path, source: str, text: str, tmp_path: Path
) -> None:
    assert _rust_spans(rust_find, source, text, tmp_path) == _python_spans(source, text)
