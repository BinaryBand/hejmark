"""cli.main: the command-line interface.

Keep it thin -- parse arguments, wire adapters into core use-cases, format results. Typer is the
standard framework: declare commands with @app.command() and describe any
arguments/options with typing.Annotated so `ty` sees real signatures.

The commands: `find` (scan a target file with a query) and `run` (execute a
whole script against a target file) are the language; `emit-json` and
`emit-program` are the same two, stopped at the compiler so another engine can
finish them, and `emit-fragments` is `emit-json` over a script a host holds in
pieces -- one AST per piece, one shared set of names; `gen-parser` (rebuild the
ANTLR parser from the grammars),
`parse-file` (dump a parse tree) and `status` (version echo) are the tooling
around it. `dev` is a hidden group of build steps for working on hejmark
itself, off the language's surface but not out of reach.
"""

from __future__ import annotations

from importlib.metadata import version
from pathlib import Path
from typing import Annotated

import click
import typer

import hejmark
from hejmark.adapters.antlr import AntlrGenerationError, AntlrGenerator, AntlrToolNotFoundError
from hejmark.adapters.parser import AntlrParser, GeneratedParserMissingError
from hejmark.adapters.toolchain import ToolchainBuilder, ToolchainError, repository_root

app = typer.Typer(add_completion=False, no_args_is_help=True)

# The developer group: build steps, not language verbs. Hidden rather than
# absent -- `hejmark --help` stays the language's surface, while
# `hejmark dev --help` documents these in full for whoever needs them. Hiding
# is the whole access control: nothing here is secret, only uninteresting to
# someone who came to match text.
dev_app = typer.Typer(add_completion=False, no_args_is_help=True)
app.add_typer(dev_app, name="dev", hidden=True, help="Build steps for working on hejmark itself.")

DEFAULT_GRAMMARS = (
    Path("static/grammar/HimarkLexer.g4"),
    Path("static/grammar/HimarkParser.g4"),
)
DEFAULT_OUTPUT_DIR = Path("hejmark/adapters/_gen")


def _own_paths(root: Path) -> tuple[list[Path], Path]:
    """The grammars and generated-parser directory of the checkout at *root*.

    Both constants above are written relative to a checkout root, which makes
    them correct only while the process stands in one. Anchoring them to a root
    found rather than assumed is what lets these commands run from anywhere
    inside the checkout -- `gui/` above all, since that is where the app's own
    build is driven from, and from there the bare constants named
    `gui/static/grammar` and failed on a directory that was never going to
    exist.
    """
    return [root / one for one in DEFAULT_GRAMMARS], root / DEFAULT_OUTPUT_DIR


def _defaults(grammar: list[Path] | None, output_dir: Path | None) -> tuple[list[Path], Path]:
    """Fill in whichever of the pair was omitted, from the checkout cwd sits in.

    A path the caller gave is left exactly as given -- that one is theirs, and
    relative to wherever they are. The checkout is therefore only looked for
    when something is actually defaulted, so generating some unrelated grammar
    somewhere else stays a thing this command can do.

    Raises:
        ToolchainError: a default is needed and cwd is not inside a checkout.
    """
    if grammar is not None and output_dir is not None:
        return grammar, output_dir
    own_grammars, own_output = _own_paths(repository_root(Path.cwd()))
    return (
        own_grammars if grammar is None else grammar,
        own_output if output_dir is None else output_dir,
    )


@app.command()
def status() -> None:
    """Print the installed package name and version -- minimal runnable seed."""
    typer.echo(f"hejmark {version('hejmark')}")


SOURCE_ARG = typer.Argument(exists=True, dir_okay=False, readable=True)


@app.command()
def find(
    query_file: Annotated[Path, SOURCE_ARG],
    target_file: Annotated[Path, SOURCE_ARG],
) -> None:
    """Scan a target file with a query, printing one line per match."""
    source = query_file.read_text().strip()
    text = target_file.read_text()
    try:
        found = list(hejmark.finditer(source, text))
    except ValueError as exc:
        msg = f"invalid query: {exc}"
        raise click.UsageError(msg) from exc
    for one in found:
        start, end = one.span
        typer.echo(f"{start}:{end}\t{text[start:end]!r}")
    typer.echo()
    typer.echo(f"{len(found)} match(es).")


@app.command()
def run(
    script_file: Annotated[Path, SOURCE_ARG],
    target_file: Annotated[Path, SOURCE_ARG],
) -> None:
    """Run a whole script against a target file, printing the spliced document."""
    try:
        result = hejmark.run(script_file.read_text(), target_file.read_text())
    except ValueError as exc:
        msg = f"invalid script: {exc}"
        raise click.UsageError(msg) from exc
    typer.echo(result, nl=False)


@app.command("gen-parser")
def gen_parser(
    grammar: Annotated[
        list[Path] | None,
        typer.Option(help="Path to a .g4 grammar file; repeat for a lexer/parser pair."),
    ] = None,
    output_dir: Annotated[
        Path | None, typer.Option(help="Directory to write generated parser sources into.")
    ] = None,
    language: Annotated[str, typer.Option(help="Target language for antlr4 -Dlanguage=.")] = (
        "Python3"
    ),
) -> None:
    """Regenerate the parser from the ANTLR grammars via the external antlr4 tool.

    Either path left out comes from the checkout the current directory sits in,
    not from the current directory, so this runs from anywhere inside one.
    """
    try:
        grammars, generated = _defaults(grammar, output_dir)
        AntlrGenerator().generate(grammars, generated, language=language)
    except (ToolchainError, AntlrToolNotFoundError, AntlrGenerationError) as exc:
        typer.echo(str(exc), err=True)
        raise typer.Exit(1) from exc
    names = ", ".join(str(path) for path in grammars)
    typer.echo(f"Generated {language} parser for {names} into {generated}")


@app.command("emit-json")
def emit_json(
    query_file: Annotated[Path, SOURCE_ARG],
    out: Annotated[
        Path | None,
        typer.Option("--out", "-o", help="Write the floor JSON here instead of the console."),
    ] = None,
) -> None:
    """Emit a query's expanded floor AST as JSON, the portable hand-off to the Rust port."""
    source = query_file.read_text().strip()
    try:
        payload = hejmark.emit_json(source)
    except ValueError as exc:
        msg = f"invalid query: {exc}"
        raise click.UsageError(msg) from exc
    if out is None:
        typer.echo(payload)
    else:
        out.write_text(payload)
        typer.echo(f"{query_file}: OK, floor JSON written to {out}")


@app.command("emit-fragments")
def emit_fragments(
    query_files: Annotated[list[Path], SOURCE_ARG],
    out: Annotated[
        Path | None,
        typer.Option("--out", "-o", help="Write the floor JSON array here instead of the console."),
    ] = None,
) -> None:
    """Emit one floor AST per query file, lowered under the names all of them declare."""
    sources = [path.read_text().strip() for path in query_files]
    try:
        payload = hejmark.emit_fragments(sources)
    except ValueError as exc:
        msg = f"invalid query: {exc}"
        raise click.UsageError(msg) from exc
    if out is None:
        typer.echo(payload)
    else:
        out.write_text(payload)
        typer.echo(f"{len(sources)} fragment(s): OK, floor JSON written to {out}")


@app.command("emit-program")
def emit_program(
    script_file: Annotated[Path, SOURCE_ARG],
    out: Annotated[
        Path | None,
        typer.Option("--out", "-o", help="Write the program JSON here instead of the console."),
    ] = None,
) -> None:
    """Emit a whole script as the versioned Program JSON, the hand-off for a remote run."""
    try:
        payload = hejmark.emit_program(script_file.read_text())
    except ValueError as exc:
        msg = f"invalid script: {exc}"
        raise click.UsageError(msg) from exc
    if out is None:
        typer.echo(payload)
    else:
        out.write_text(payload)
        typer.echo(f"{script_file}: OK, program JSON written to {out}")


@app.command("parse-file")
def parse_file(
    path: Annotated[Path, typer.Argument(help="Path to a .hmk source file to parse.")],
    out: Annotated[
        Path | None,
        typer.Option("--out", "-o", help="Write the parse tree here instead of the console."),
    ] = None,
) -> None:
    """Parse a hejmark source file, reporting syntax errors or dumping its parse tree."""
    source = path.read_text()
    parser = AntlrParser()
    try:
        errors = parser.parse(source)
    except GeneratedParserMissingError as exc:
        typer.echo(str(exc), err=True)
        raise typer.Exit(1) from exc
    if errors:
        for error in errors:
            typer.echo(f"{path}: {error}", err=True)
        raise typer.Exit(1)
    tree = parser.parse_tree(source)
    if out is None:
        typer.echo(tree)
    else:
        out.write_text(tree)
        typer.echo(f"{path}: OK, parse tree written to {out}")


@dev_app.command()
def compile(  # noqa: A001 -- the CLI verb; it shadows the builtin in this module only
    host_only: Annotated[
        bool, typer.Option("--host-only", help="Skip the Android cross-compile (no NDK needed).")
    ] = False,
) -> None:
    """Build the parser and engine a Flutter bundle is assembled over.

    Every path it touches hangs off the checkout, found from the current
    directory rather than assumed to be it -- so this is runnable from `gui/`,
    which is where the rest of the app's build is run from.
    """
    builder = ToolchainBuilder()
    try:
        root = repository_root(Path.cwd())
        grammars, generated = _own_paths(root)
        AntlrGenerator().generate(grammars, generated, language="Python3")
        typer.echo(f"parser: OK, generated into {generated}")
        for step in builder.steps(root, host_only=host_only):
            typer.echo(f"{step.name}: {' '.join(step.argv)}")
            builder.run(step)
    except (ToolchainError, AntlrToolNotFoundError, AntlrGenerationError) as exc:
        typer.echo(str(exc), err=True)
        raise typer.Exit(1) from exc
    typer.echo("engine: OK")


def main() -> None:
    """Run the command-line interface."""
    app()
