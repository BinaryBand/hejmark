"""cli.main: the command-line interface.

Keep it thin -- parse arguments, wire adapters into core use-cases, format results. Typer is the
standard framework: declare commands with @app.command() and describe any
arguments/options with typing.Annotated so `ty` sees real signatures. A Typer
app needs at least one command to run, so `status` below is the minimal runnable
seed -- add your own commands alongside it or replace it. While it is the only
command, Typer runs it directly (invoke the app as `Himark`, not
`Himark status`); it becomes a named subcommand once a second is added.
"""

from __future__ import annotations

from importlib.metadata import version
from pathlib import Path
from typing import Annotated

import typer

from Himark.adapters.antlr import AntlrGenerationError, AntlrGenerator, AntlrToolNotFoundError
from Himark.adapters.parser import AntlrParser, GeneratedParserMissingError

app = typer.Typer(add_completion=False, no_args_is_help=True)

DEFAULT_GRAMMARS = (
    Path("static/grammar/HimarkLexer.g4"),
    Path("static/grammar/HimarkParser.g4"),
)
DEFAULT_OUTPUT_DIR = Path("Himark/adapters/_gen")


@app.command()
def status() -> None:
    """Print the installed package name and version -- minimal runnable seed."""
    typer.echo(f"Himark {version('Himark')}")


@app.command("gen-parser")
def gen_parser(
    grammar: Annotated[
        list[Path] | None,
        typer.Option(help="Path to a .g4 grammar file; repeat for a lexer/parser pair."),
    ] = None,
    output_dir: Annotated[
        Path, typer.Option(help="Directory to write generated parser sources into.")
    ] = DEFAULT_OUTPUT_DIR,
    language: Annotated[str, typer.Option(help="Target language for antlr4 -Dlanguage=.")] = (
        "Python3"
    ),
) -> None:
    """Regenerate the parser from the ANTLR grammars via the external antlr4 tool."""
    grammars = list(DEFAULT_GRAMMARS) if grammar is None else grammar
    try:
        AntlrGenerator().generate(grammars, output_dir, language=language)
    except (AntlrToolNotFoundError, AntlrGenerationError) as exc:
        typer.echo(str(exc), err=True)
        raise typer.Exit(1) from exc
    names = ", ".join(str(path) for path in grammars)
    typer.echo(f"Generated {language} parser for {names} into {output_dir}")


@app.command("parse-file")
def parse_file(
    path: Annotated[Path, typer.Argument(help="Path to a .hmk source file to parse.")],
    out: Annotated[
        Path | None,
        typer.Option("--out", "-o", help="Write the parse tree here instead of the console."),
    ] = None,
) -> None:
    """Parse a Himark source file, reporting syntax errors or dumping its parse tree."""
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


def main() -> None:
    """Run the command-line interface."""
    app()
