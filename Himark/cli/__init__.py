"""cli: command-line entry points and argument parsing.

The only layer that may import from app. Keep it thin -- parse arguments,
call into app, format results. May use print() for output.
"""

from __future__ import annotations


def main() -> None:
    """Run the command-line interface."""
