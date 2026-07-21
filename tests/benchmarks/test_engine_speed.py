"""Benchmark: the Rust engine against the Python one, over the same queries.

Rides the hand-off tests/integration/test_rust_bridge.py already proves correct
-- ``hejmark.emit_json`` lowers a query to the floor AST as JSON, the Rust
``find`` binary decodes, denotes and scans -- and times both ends. The spans are
asserted equal on every row, so a benchmark that drifts out of agreement fails
rather than quietly comparing two different computations; the timings themselves
assert nothing, because a wall clock on a loaded machine is not a gate.

Both engines are measured cold. Python's ``_contains`` memo is an unbounded-ish
lru_cache shared across calls, and leaving it warm from a previous case makes a
scan up to three times faster -- so it is cleared before each timed run, which
also matches the Rust side, cold by construction in a fresh process.
"""

from __future__ import annotations

import subprocess
import time
from pathlib import Path

import pytest

import hejmark
from hejmark.core.floor import universe

pytestmark = pytest.mark.benchmark


def _corpus(repeat: int) -> str:
    """A target with dense hits for every scaling query below."""
    return ("banana split " * repeat) + ("abc123 " * repeat)


# One query per floor constructor emit_json can lower -- face, union, product,
# range, fold, subtraction, digits -- at two target sizes. Python's scan cost
# grows superlinearly in the target, so the pair shows the curve rather than a
# single point; the sizes are chosen to keep the whole run near ten seconds.
SCALING = [
    "{a}",
    "{a,b}",
    "{a}{b}",
    "{a..e}",
    "{{cat,feline}}",
    "{a..c, !{b}, b}",
    "{0..9}",
]

CASES = [(source, _corpus(repeat)) for repeat in (10, 40) for source in SCALING]

# The closure gets its own tiny target, and the size is pinned deliberately.
# rust/src/floor/universe.rs states that the port omits Python's `_contains`
# lru_cache ("a performance optimization ... omits it for now"), which leaves
# closure membership exponential in the target length there and memoized here --
# the one row where Rust loses, and the point of measuring at all. Nine
# characters costs the Rust side a few hundred milliseconds; eleven costs
# seconds, so do not grow this text without re-timing it.
CASES.append(("{a, &{b}}", "abbb a ab"))

IDS = [f"{source} @{len(text)}" for source, text in CASES]


def _python_scan(source: str, text: str) -> tuple[list[tuple[int, int]], float]:
    """Scan with the Python engine from a cleared memo; return spans and elapsed ms."""
    universe._contains.cache_clear()
    start = time.perf_counter()
    spans = [found.span for found in hejmark.finditer(source, text)]
    return spans, (time.perf_counter() - start) * 1000


def _rust_scan(
    binary: Path, source: str, text: str, tmp_path: Path
) -> tuple[list[tuple[int, int]], float]:
    """Emit *source* as JSON, run the binary over *text*; return spans and elapsed ms."""
    query_json = tmp_path / "query.json"
    target = tmp_path / "target.txt"
    query_json.write_text(hejmark.emit_json(source))
    target.write_text(text)
    start = time.perf_counter()
    result = subprocess.run(
        [str(binary), str(query_json), str(target)],
        capture_output=True,
        text=True,
        check=True,
    )
    elapsed = (time.perf_counter() - start) * 1000
    spans: list[tuple[int, int]] = []
    for line in result.stdout.splitlines():
        start_offset, end_offset = line.split("\t")
        spans.append((int(start_offset), int(end_offset)))
    return spans, elapsed


@pytest.mark.parametrize(("source", "text"), CASES, ids=IDS)
def test_engine_speed(
    rust_find: Path,
    rows: list[tuple[str, int, float, float]],
    source: str,
    text: str,
    tmp_path: Path,
) -> None:
    """Time both engines on one query and record the row; the spans must agree."""
    python_spans, python_ms = _python_scan(source, text)
    rust_spans, rust_ms = _rust_scan(rust_find, source, text, tmp_path)
    rows.append((source, len(text), python_ms, rust_ms))
    assert rust_spans == python_spans
