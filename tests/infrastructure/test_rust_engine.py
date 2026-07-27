"""CI gate: the Rust engine under rust/ builds and meets the corpus.

Two checks, and the split between them is the point.

`cargo test` runs `rust/tests/conformance.rs`, which reads
`static/conformance/*.json` **directly** -- no wire, no Python. That is the gate
that actually constrains the engine, because the protocol has verbs for `run`,
`zero` and `digits` and none for entries or membership: the `denote` and `match`
suites cannot be asked over a pipe at all. An engine that reported the matcher's
greedy split instead of the floor's least-address binding would pass everything
a wire can carry.

The transport check then runs the corpus's `run` suite over a real pipe against
the built binary, which is the other half: the engine is correct *and* it speaks
the protocol. `HEJMARK_SKIP_RUST=1` opts out of both, the way `HEJMARK_SKIP_LEAN`
does, so a checkout without a cargo toolchain can still run everything else.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest

from hejmark.adapters.library import standard_library
from hejmark.adapters.parser import AntlrParser
from hejmark.adapters.remote import connect
from hejmark.core.driver import Adapters, run

ROOT = Path(__file__).resolve().parents[2]
CRATE = ROOT / "rust"
BINARY = CRATE / "target" / "release" / "hejmark-engine"

# Long enough for a cold `cargo build` that fetches and compiles serde_json.
BUILD_SECONDS = 900


def _skip_unless_wanted() -> None:
    """Opt out only when asked to, so a missing toolchain fails loudly."""
    if os.environ.get("HEJMARK_SKIP_RUST") == "1":
        pytest.skip("HEJMARK_SKIP_RUST=1 set; the Rust engine is not checked")


def test_rust_engine_meets_the_conformance_corpus() -> None:
    """The corpus, read natively: what a port has to pass to be an engine."""
    _skip_unless_wanted()
    result = subprocess.run(
        ["cargo", "test", "--release"],
        cwd=CRATE,
        capture_output=True,
        text=True,
        timeout=BUILD_SECONDS,
        check=False,
    )
    assert result.returncode == 0, f"cargo test failed:\n{result.stdout}\n{result.stderr}"


def test_rust_engine_speaks_the_protocol() -> None:
    """The same corpus over a real pipe, against the binary a host would spawn."""
    _skip_unless_wanted()
    build = subprocess.run(
        ["cargo", "build", "--release"],
        cwd=CRATE,
        capture_output=True,
        text=True,
        timeout=BUILD_SECONDS,
        check=False,
    )
    assert build.returncode == 0, f"cargo build failed:\n{build.stderr}"
    cases = json.loads((ROOT / "static" / "conformance" / "run.json").read_text())["cases"]
    library = standard_library()
    with connect([str(BINARY)]) as engine:
        adapters = Adapters(AntlrParser().to_ast, engine)
        for case in cases:
            spliced = run(adapters, case["source"], case["document"], library)
            assert spliced == case["output"], case["name"]
