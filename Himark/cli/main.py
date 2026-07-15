"""cli.main: the command-line interface.

Keep it thin -- parse arguments, call into app, format results.  Typer is the
standard framework; commands are registered via :func:`Himark.cli.registry.command`
and wired here.  When invoked with no arguments in an interactive terminal, the
app presents a numbered picker so the user can select a command.
"""

from __future__ import annotations

import sys
from typing import cast

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
    # Enumeration lives on click.Group; guard in case the app collapsed to a
    # single bare Command (no group), which has no subcommands to list.
    group = ctx.command
    if not isinstance(group, click.Group):
        raise click.UsageError(_NO_COMMAND_MSG)

    click_ctx = cast("click.Context", ctx)

    commands_list = group.list_commands(click_ctx)
    print("\n  Himark \u2014 a query language over pointed alphabets\n")
    for idx, name in enumerate(commands_list, 1):
        cmd_obj = group.get_command(click_ctx, name)
        help_text = cmd_obj.get_short_help_str() if cmd_obj else ""
        print(f"  {idx}. {name:20s} {help_text}")
    print()

    try:
        raw = input("Select a command: ").strip()
        choice = int(raw) - 1
    except (ValueError, EOFError):
        raise SystemExit(_INVALID_SELECTION_MSG) from None

    if not 0 <= choice < len(commands_list):
        raise SystemExit(_INVALID_SELECTION_MSG)
    selected = commands_list[choice]

    cmd_obj = group.get_command(click_ctx, selected)
    if cmd_obj is None:
        raise SystemExit(_INVALID_SELECTION_MSG)
    ctx.invoke(cmd_obj)


def main() -> None:
    """Run the command-line interface."""
    app()
