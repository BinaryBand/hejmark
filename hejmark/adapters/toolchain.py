"""adapters.toolchain: locating the checkout a developer build step runs against.

The developer-facing sibling of :mod:`hejmark.adapters.antlr`. That one runs the
generator this package's parser is built from; this one answers the question in
front of it -- *which checkout am I in?* -- since ``hejmark gen-parser`` writes
into the tree rather than into the current directory, and a run from outside a
checkout should say so rather than half-succeed.

Nothing here is on a user's path, but it is a real adapter under the same
layering rule as every other: ``core`` cannot touch the filesystem, so looking
one up lives here.
"""

from __future__ import annotations

from pathlib import Path


class ToolchainError(RuntimeError):
    """Raised when a build step cannot find the tree it is meant to run against."""


def repository_root(start: Path) -> Path:
    """The checkout *start* sits in: the nearest ancestor holding ``pyproject.toml``.

    Raises:
        ToolchainError: no ancestor of *start* is a hejmark checkout.
    """
    for directory in [start.resolve(), *start.resolve().parents]:
        if (directory / "pyproject.toml").is_file():
            return directory
    msg = f"{start} is not inside a hejmark checkout (needs pyproject.toml)"
    raise ToolchainError(msg)
