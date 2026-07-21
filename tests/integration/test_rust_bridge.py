"""Cross-language bridge: Python compiles, Rust denotes and executes.

The two engines must agree, and they meet at two payloads that nest. A **query**
crosses as ``hejmark.emit_json`` (parse + expand + encode) into ``floor::json``
into ``denote`` and the matcher, and the spans must be equal. A whole **script**
crosses as ``hejmark.emit_program`` into ``ir::wire`` into ``execute``, and the
spliced documents must be equal -- the same hand-off one layer up, with a
compiled query at each of its leaves.

The one thing the Rust end cannot do is the thing that is not data: a
back-referencing factor rides the program as a late slot and resolving it is a
call into the compiler that emitted it, so those scripts are pinned to refuse by
name rather than left out of the table.

Skips cleanly when the Rust toolchain or tree is absent, the way tests/test_rust.py does.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

import hejmark

ROOT = Path(__file__).resolve().parents[2]
RUST = ROOT / "rust"
EXAMPLES = ROOT / "static" / "examples"

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


# Shipped scripts that lower without a back-reference, with a document each.
# The expected output is not written down: `hejmark.run` is the oracle, so the
# assertion is agreement rather than a second copy of test_examples.py's table.
SCRIPTS = [
    ("demos/emit.hmk", "my feline"),
    ("demos/synonyms.hmk", "my kitty met your feline"),
    ("demos/mask-replace.hmk", "cat catalog"),
    ("demos/sort-swap.hmk", "bbaa"),
    ("programs/html-escape.hmk", '<a href="x">Tom & Jerry</a>'),
    ("programs/normalize-space.hmk", "a  \t b\n\nc"),
    ("programs/slugify.hmk", "Héllo, World!"),
]

# The two shipped scripts that back-reference, and so cannot leave the process
# that compiled them. Their query factor index is what the refusal names.
LATE_SCRIPTS = [
    ("demos/double-letter.hmk", "book keeper", 2),
    ("demos/bubble-sort.hmk", "3,1,2", 4),
]


def _build(binary: str) -> Path:
    """Build one Rust binary once and return its path, skipping without cargo."""
    if not RUST.exists():
        pytest.skip("no rust/ tree")
    if shutil.which("cargo") is None:
        pytest.skip("cargo not on PATH")
    build = subprocess.run(
        ["cargo", "build", "--quiet", "--bin", binary],
        cwd=RUST,
        capture_output=True,
        text=True,
        check=False,
    )
    if build.returncode != 0:
        pytest.fail(f"cargo build --bin {binary} failed:\n{build.stdout}\n{build.stderr}")
    return RUST / "target" / "debug" / binary


@pytest.fixture(scope="module")
def rust_find() -> Path:
    """Build the Rust ``find`` binary once and return its path."""
    return _build("find")


@pytest.fixture(scope="module")
def rust_run() -> Path:
    """Build the Rust ``run`` binary once and return its path."""
    return _build("run")


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


def _rust_run(
    binary: Path, source: str, document: str, tmp_path: Path
) -> subprocess.CompletedProcess[str]:
    """Emit *source* as a program, run the Rust binary over *document*."""
    program = tmp_path / "program.json"
    target = tmp_path / "target.txt"
    program.write_text(hejmark.emit_program(source))
    target.write_text(document)
    return subprocess.run(
        [str(binary), str(program), str(target)],
        capture_output=True,
        text=True,
        check=False,
    )


@pytest.mark.parametrize(("name", "document"), SCRIPTS)
def test_rust_run_agrees_with_python(
    rust_run: Path, name: str, document: str, tmp_path: Path
) -> None:
    """A whole script spliced by Rust is the document Python splices."""
    source = (EXAMPLES / name).read_text()
    result = _rust_run(rust_run, source, document, tmp_path)
    assert result.returncode == 0, result.stderr
    assert result.stdout == hejmark.run(source, document)


@pytest.mark.parametrize(("name", "document", "factor"), LATE_SCRIPTS)
def test_rust_refuses_a_back_referencing_script_by_name(
    rust_run: Path, name: str, document: str, factor: int, tmp_path: Path
) -> None:
    """A late slot is refused at load, and Python still runs the same script."""
    source = (EXAMPLES / name).read_text()
    result = _rust_run(rust_run, source, document, tmp_path)
    assert result.returncode == 1
    assert f"factor {factor} back-references" in result.stderr
    assert hejmark.run(source, document)  # the compiler that emitted it still can
