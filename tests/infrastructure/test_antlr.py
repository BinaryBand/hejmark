"""CI gate: the ANTLR surface grammar generates cleanly and parses the L1 north-star."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import TYPE_CHECKING

import pytest
from antlr4 import CommonTokenStream, InputStream
from antlr4.error.ErrorListener import ErrorListener

if TYPE_CHECKING:
    from collections.abc import Callable, Iterator

ROOT = Path(__file__).resolve().parents[2]
GRAMMARS = (
    ROOT / "static" / "grammar" / "HimarkLexer.g4",
    ROOT / "static" / "grammar" / "HimarkParser.g4",
)
EXAMPLES = ROOT / "static" / "examples"

# ANTLR reports hard failures as `error(NNN):` lines and ambiguity/left-recursion
# problems as `warning(NNN):` lines. Warnings do not change the exit code, so the
# build gate scans for both rather than trusting the return code alone. The
# `antlr4` launcher's own version chatter never matches this shape.
DIAGNOSTIC = re.compile(r"^(?:error|warning)\(\d+\):", re.MULTILINE)

# Representative rows from docs/foundation/L1.md's north-star: one per
# constructor, both boundary objects, and the two forms the grammar was widened
# to accept (whitespace between tokens, multi-char range endpoints). If the
# surface stops admitting any L1 shape, one of these stops parsing.
NORTH_STAR_ROWS = (
    "{a,b,c}",  # union
    "{a..z}",  # bounded range (compression)
    "{aa..zz}",  # multi-char range endpoints
    "{a..z, !{a,e,i,o,u}}",  # subtraction, with whitespace after the comma
    "{{cat,feline}}",  # fold
    "{{cat,feline}, !{feline}}",  # subtraction strips a face, entry survives
    "{a..}",  # final segment
    "{cat}{dog}",  # product (finite adjacency)
    "{a,ab}{b,c}",  # product, values 0-3
    "{a,ab}{c,bc}",  # product with a colliding seam
    "{a..}{b}",  # product over a closure factor (order type omega)
    "{b,c}{a..}",  # the omega*2 north-star row
    "{b}{a..}{b}{a..}",  # the seam row (order type omega^2)
    "{a..}{a..}",  # cofinite collision collapse (order type omega*k)
    "{a,!{a}}",  # empty universe (subtraction to nothing)
    "{z..a}",  # empty universe (reversed range)
    "{}",  # empty universe
    "{{}}",  # unit universe
    "{{{},0}}",  # the fill factor (fold of the unit with a spelling)
    "{{{},0}}{{{},0}}",  # Z^2, colliding faces
    "{{{},0}}{0..9}",  # a face axis, not an entry axis
    "{{{},0}}{0,00}",  # cross-axis collision, canonical face renumbers
    "{a, &{b}}",  # closure
    "{ab, {a}&{b}}",  # guarded closure -- the admission witness a^n b^n
    "{0, {1..9, &{0..9}}}",  # canonical numerals
    "{{{}}, &C}",  # every spelling in shortlex (final segment's demotion)
    "{&}",  # bare self-reference builds nothing
    "{a, &}",  # self-union no-ops
    "{a.., !{&}}",  # negative self-reference
    "{a, {{{},0}}&}",  # unguarded fill
    "{ab, &&}",  # nonlinear closure, still type omega
    "{ {(}{b}{a..}{)}, {(}&&{)} }",  # nonlinear closure, heavily spaced
)

# Representative L1.5 surface shapes from docs/foundation/L1_5.md: the
# declaration forms, the std derivations' register/exponent/operand spellings,
# the modifier pipeline, and each emit-statement shape from the north-star
# table (an empty input is likewise a legal, empty script).
L1_5_ROWS = (
    "uni d = {0..9}",  # declaration
    "uni spellings = {{{}}, &@C}",  # the seeded std universe
    "fill := {{{}, @0}}",  # zero-parameter definition over a register
    "nonzero := {@, !{@0}}",  # bare head register
    "where lo..hi := {@numerals, !{@numerals, !{ {lo..hi} }}}",  # pair parameter
    "pad w..w' := {@fill^{w'} _, !{@shorter w}, !{@longer w'}}",  # exponent + operand token
    "{0..9}[where 8..12 pad 1..2]",  # modifier pipeline
    '{{cat,feline}} => "{{$0}}"',  # emit: canonical-face rewrite
    '{a,e,i,o,u} => ""',  # emit: deletion
    '{@spellings} => "<b>{{$}}</b>"',  # emit: whole-document idiom
    '"seed" => {e} => "E"',  # emit: detached string chain
    'uni d = {0..9}\n{a} => {b}\n  => "x"',  # line discipline + arrow continuation
    "",  # the empty script
)

# Shapes the grammar must reject: a parser that accepts everything is no gate.
MALFORMED = (
    "{a",  # unbalanced brace
    "{a,}",  # trailing comma
    "{,a}",  # leading comma
    "a,b",  # bare members outside a universe
    "{a} =>",  # dangling arrow -- a step must follow
)


class _CollectingErrorListener(ErrorListener):
    """Records syntax errors as strings instead of printing them to stderr."""

    def __init__(self) -> None:
        self.errors: list[str] = []

    def syntaxError(self, *args) -> None:  # noqa: N802  # ty: ignore[invalid-method-override]
        # ANTLR calls this positionally: recognizer, offendingSymbol, line,
        # column, msg, e. Only the location and message are recorded.
        _recognizer, _offending, line, column, msg, _exc = args
        self.errors.append(f"{line}:{column} {msg}")


@pytest.fixture(scope="module")
def antlr_build() -> Iterator[tuple[subprocess.CompletedProcess[str], Path]]:
    """Generate the Python parser once from the committed grammar.

    The `antlr4` generator is an external toolchain (the runtime is a pinned
    dependency, but the code generator is not). A missing generator fails
    loudly rather than silently skipping, mirroring the Lean gate: set
    ``HIMARK_SKIP_ANTLR=1`` to opt out deliberately. Yields the completed run
    and the temp dir holding the generated modules, torn down with the fixture.
    """
    if os.environ.get("HIMARK_SKIP_ANTLR") == "1":
        pytest.skip("HIMARK_SKIP_ANTLR=1 set; ANTLR grammar not checked")
    tool = shutil.which("antlr4")
    if tool is None:
        pytest.fail("antlr4 not found on PATH; set HIMARK_SKIP_ANTLR=1 to opt out")
    with tempfile.TemporaryDirectory() as tmp:
        workdir = Path(tmp)
        for grammar in GRAMMARS:
            shutil.copy(grammar, workdir / grammar.name)
        result = subprocess.run(
            [tool, "-Dlanguage=Python3", *(grammar.name for grammar in GRAMMARS)],
            capture_output=True,
            text=True,
            cwd=workdir,
            check=False,
        )
        yield result, workdir


@pytest.fixture(scope="module")
def parse(
    antlr_build: tuple[subprocess.CompletedProcess[str], Path],
) -> Iterator[Callable[[str], list[str]]]:
    """Yield a parser that returns the syntax errors raised over a source string.

    Imports the freshly generated lexer/parser from the temp dir on ``sys.path``
    and attaches a collecting error listener to both, so lexer and parser errors
    alike surface as strings. Empty list means the input parsed cleanly.
    """
    result, workdir = antlr_build
    if result.returncode != 0:
        pytest.fail(f"cannot parse: generation failed:\n{result.stderr}")
    sys.path.insert(0, str(workdir))
    try:
        from HimarkLexer import HimarkLexer  # noqa: PLC0415  # ty: ignore[unresolved-import]
        from HimarkParser import HimarkParser  # noqa: PLC0415  # ty: ignore[unresolved-import]

        def _parse(text: str) -> list[str]:
            listener = _CollectingErrorListener()
            lexer = HimarkLexer(InputStream(text))
            lexer.removeErrorListeners()
            lexer.addErrorListener(listener)
            parser = HimarkParser(CommonTokenStream(lexer))
            parser.removeErrorListeners()
            parser.addErrorListener(listener)
            parser.script()
            return listener.errors

        yield _parse
    finally:
        sys.path.remove(str(workdir))
        for module in ("HimarkLexer", "HimarkParser", "HimarkParserListener"):
            sys.modules.pop(module, None)


def test_antlr_grammar_generates_cleanly(
    antlr_build: tuple[subprocess.CompletedProcess[str], Path],
) -> None:
    """`antlr4` must generate the parser with no errors and no warnings.

    A nonzero exit catches hard errors; the diagnostic scan catches ambiguity
    and other `warning(NNN)` reports that ANTLR emits without failing the run.
    """
    result, _ = antlr_build
    assert result.returncode == 0, (
        f"antlr4 generation failed (exit {result.returncode}):\n\n{result.stdout}\n{result.stderr}"
    )
    diagnostics = DIAGNOSTIC.findall(result.stdout + result.stderr)
    assert not diagnostics, (
        f"antlr4 reported grammar diagnostics:\n\n{result.stdout}\n{result.stderr}"
    )


def test_antlr_grammar_parses_north_star(parse: Callable[[str], list[str]]) -> None:
    """Every north-star row from L1.md must parse under the surface grammar."""
    failures = {row: errors for row in NORTH_STAR_ROWS if (errors := parse(row))}
    assert not failures, f"north-star rows failed to parse: {failures}"


def test_antlr_grammar_parses_l1_5_surface(parse: Callable[[str], list[str]]) -> None:
    """Every L1.5 surface row from L1_5.md must parse under the surface grammar."""
    failures = {row: errors for row in L1_5_ROWS if (errors := parse(row))}
    assert not failures, f"L1.5 surface rows failed to parse: {failures}"


def test_antlr_grammar_parses_examples(parse: Callable[[str], list[str]]) -> None:
    """Every committed `static/examples/*.hmk` program must parse."""
    examples = sorted(EXAMPLES.glob("*.hmk"))
    assert examples, f"no example programs found under {EXAMPLES}"
    failures = {path.name: errors for path in examples if (errors := parse(path.read_text()))}
    assert not failures, f"example programs failed to parse: {failures}"


def test_antlr_grammar_rejects_malformed(parse: Callable[[str], list[str]]) -> None:
    """Malformed input must raise at least one syntax error, so the gate has teeth."""
    accepted = [text for text in MALFORMED if not parse(text)]
    assert not accepted, f"malformed input was accepted without error: {accepted}"
