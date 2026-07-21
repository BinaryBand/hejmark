"""Benchmark: the Rust engine against the Python one, over the same queries.

Rides the hand-off tests/integration/test_rust_bridge.py already proves correct
-- ``hejmark.emit_json`` lowers a query to the floor AST as JSON, the Rust
``find`` binary decodes, denotes and scans -- and times both ends.

Both engines are measured cold. Python's memos are lru_caches shared across
calls, and leaving one warm from a previous case makes a scan several times
faster -- so they are cleared before each timed run, which also matches the Rust
side, cold by construction in a fresh process. The remembered hash on
``UniverseNode`` needs no clearing: each row re-parses, so its nodes are new.

Rust wins every row again. It briefly did not: Python took four rewrites the
port lacked, and for a while won every 800-character row. The port has since
carried all four across -- the two-ended cut bound (``rust/src/floor/reach.rs``),
the membership memo, the chart, and a node identity that stands in for Python's
remembered hash -- plus a fifth the Python never needed, since sharing the AST
behind ``Rc`` removed a deep subtree copy per candidate cut.

Read the two halves differently, and read neither as a measure of the scan. The
800-character rows now sit near a millisecond, which is process spawn and JSON
decode rather than matching, so they say only that the scan is no longer the
cost. The 200-character rows say less still: Python's parse and first-call
warm-up dominate its own number there.

The spans are asserted equal on every row, so a benchmark that drifts out of
agreement fails; the timings themselves still assert nothing, because a wall
clock on a loaded machine is not a gate.
"""

from __future__ import annotations

import subprocess
import time
from pathlib import Path

import pytest

import hejmark
from hejmark.core.floor import reach, universe

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

# The closure gets its own tiny target. It used to be the row where Rust lost --
# the port had no membership memo, so closure membership was exponential in the
# target length there and memoized here, and nine characters cost the Rust side
# a few hundred milliseconds. Both engines now memoize it and the row runs in
# under a millisecond either way.
#
# The target stays small anyway, because the closure at omega is superlinear in
# both engines however well memoized: `{a, &{a}}` over 400 characters costs Rust
# 8.5 s and Python considerably more. Do not grow this text without re-timing it.
CASES.append(("{a, &{b}}", "abbb a ab"))

IDS = [f"{source} @{len(text)}" for source, text in CASES]


def _python_scan(source: str, text: str) -> tuple[list[tuple[int, int]], float]:
    """Scan with the Python engine from a cleared memo; return spans and elapsed ms."""
    universe._contains.cache_clear()
    universe._spells.cache_clear()
    reach.reach.cache_clear()
    reach.suffixes.cache_clear()
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
