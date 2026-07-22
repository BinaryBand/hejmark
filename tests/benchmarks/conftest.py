"""Shared plumbing for the engine benchmarks: the release binary and the summary table.

The benchmarks are opt-in (``-m benchmark``; pyproject's addopts deselect them),
so they can afford both a release build and target sizes large enough for the
Python engine's superlinear scan cost to show.
"""

from __future__ import annotations

from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]

# One row per timed case: (query source, target length, python ms, rust ms).
# The tests append; pytest_terminal_summary below drains into a table. Going
# through the reporter rather than print() is what makes the numbers survive
# pytest's output capture without the suite needing -s.
Row = tuple[str, int, float, float]
ROWS: list[Row] = []


@pytest.fixture
def rows() -> list[Row]:
    """The accumulator the summary table drains."""
    return ROWS


def pytest_terminal_summary(terminalreporter: pytest.TerminalReporter) -> None:
    """Print the benchmark table once the run is over."""
    if not ROWS:
        return
    write = terminalreporter.write_line
    write("")
    write("Rust (release) vs Python engine -- one cold scan per row")
    write(f"{'query':<20}{'chars':>7}{'python':>13}{'rust':>13}{'speedup':>10}")
    for source, size, python_ms, rust_ms in ROWS:
        speedup = f"{python_ms / rust_ms:.1f}x"
        write(f"{source:<20}{size:>7}{python_ms:>10.1f} ms{rust_ms:>10.1f} ms{speedup:>10}")
    write("")
    write("Python timings cover parse, expand, denote and scan; Rust's add process")
    write("spawn and JSON decode but skip parse/expand, which Python does for both.")
    write("A speedup below 1.0x is Rust losing -- see the closure note in the module.")
