"""cli.main: the command-line interface.

Keep it thin -- parse arguments, call into app, format results.  Typer is the
standard framework; commands are registered via :func:`Himark.cli.registry.command`
and wired here.  When invoked with no arguments in an interactive terminal, the
app presents a numbered picker so the user can select a command.
"""

from __future__ import annotations

import sys

import click
import typer

from Himark.cli import commands  # noqa: F401 -- triggers @command registration
from Himark.cli.registry import wire

_NO_COMMAND_MSG = "No command specified. Run with --help for usage."
_INVALID_SELECTION_MSG = "Invalid selection."

app = typer.Typer(add_completion=False, no_args_is_help=False, invoke_without_command=True)
wire(app)


@app.callback(invoke_without_command=True)
def _main_callback(ctx: typer.Context) -> None:
    """Himark: a query language over pointed alphabets."""
    if ctx.invoked_subcommand is not None:
        return

    # Non-interactive (piped / CI): fail loudly with actionable guidance.
    if not sys.stdin.isatty():
        raise click.UsageError(_NO_COMMAND_MSG)

    # Interactive picker: enumerate registered commands and let the user choose.
    commands_list = ctx.command.list_commands(ctx)
    print("\n  Himark \u2014 a query language over pointed alphabets\n")
    for idx, name in enumerate(commands_list, 1):
        cmd_obj = ctx.command.get_command(ctx, name)
        help_text = cmd_obj.get_short_help_str(ctx) if cmd_obj else ""
        print(f"  {idx}. {name:20s} {help_text}")
    print()

    try:
        raw = input("Select a command: ").strip()
        choice = int(raw) - 1
        selected = commands_list[choice]
    except (ValueError, IndexError, EOFError):
        raise SystemExit(_INVALID_SELECTION_MSG) from None

    cmd_obj = ctx.command.get_command(ctx, selected)  # ty: ignore[unresolved-attribute]
    ctx.invoke(cmd_obj)


def main() -> None:
    """Run the command-line interface."""
    app()
