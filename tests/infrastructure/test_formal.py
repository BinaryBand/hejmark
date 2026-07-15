"""CI gate: the Coq mechanization under static/formal/ builds and is axiom-free."""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
FORMAL = ROOT / "static" / "formal"

# Vernacular that would leave a statement unproven or postulated. A dumb
# line-start regex is enough to keep the development honest: none of these
# tokens has a legitimate top-level use in this tree.
FORBIDDEN = re.compile(
    r"^\s*(Admitted\b|admit\b|Axiom\b|Axioms\b|Parameter\b|Parameters\b"
    r"|Conjecture\b|Hypothesis\b|Hypotheses\b)"
)


def test_formal_proofs_build() -> None:
    """dune build must succeed, so every proof checks end to end.

    Coq and dune are opam-installed system tools. A missing toolchain fails
    this test loudly rather than silently skipping it, so contributors must
    set ``HIMARK_SKIP_FORMAL=1`` explicitly to opt out.
    """
    if os.environ.get("HIMARK_SKIP_FORMAL") == "1":
        pytest.skip("HIMARK_SKIP_FORMAL=1 set; formal proofs not checked")
    result = subprocess.run(
        ["dune", "build"], capture_output=True, text=True, cwd=FORMAL, check=False
    )
    assert result.returncode == 0, (
        f"dune build failed (exit {result.returncode}):\n\n{result.stdout}\n{result.stderr}"
    )


def test_formal_proofs_are_complete() -> None:
    """No Coq source may contain an axiom, an admit, or any unproven escape hatch.

    Pure text gate: it needs no toolchain and is never skipped, so a proof
    stubbed out with ``Admitted`` (or an alphabet postulated with
    ``Parameter``) fails the suite even where Coq is not installed.
    """
    offenders: list[str] = []
    for path in sorted(FORMAL.rglob("*.v")):
        if "_build" in path.parts:
            continue
        for number, line in enumerate(path.read_text().splitlines(), start=1):
            if FORBIDDEN.match(line):
                offenders.append(f"{path.relative_to(ROOT)}:{number}: {line.strip()}")
    listing = "\n".join(offenders)
    assert not offenders, f"formal sources contain unproven escape hatches:\n\n{listing}"
