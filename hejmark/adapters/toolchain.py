"""adapters.toolchain: shells out to the build tools the app is bundled from.

The developer-facing sibling of :mod:`hejmark.adapters.antlr`. That one runs the
generator this package's parser is built from; this one runs the *other* halves
a Flutter build needs in front of it -- ``cargo`` for the Rust engine, and the
GUI's own ``tool/build_engine.sh`` for the C-ABI shared library the app loads.

It exists so that ``hejmark dev compile`` is wiring rather than a shell script
in disguise: the steps are data (:class:`Step`), the invocation is one place,
and a missing tool is a sentence rather than a traceback. Nothing here is on a
user's path -- the command that drives it is hidden -- but it is a real adapter
under the same layering rule as every other: ``core`` cannot shell out, so this
is where shelling out lives.
"""

from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path


class ToolchainError(RuntimeError):
    """Raised when a build step is unreachable or exits non-zero."""


@dataclass(frozen=True)
class Step:
    """One build step: what to say it is, what to run, and where to run it."""

    name: str
    argv: tuple[str, ...]
    cwd: Path


def repository_root(start: Path) -> Path:
    """The checkout *start* sits in: the nearest ancestor holding ``rust/``.

    The same marker pair ``gui/lib/models/bridge.dart`` looks for, for the same
    reason -- these tools only exist inside a checkout, and a build run from
    anywhere else should say so rather than half-succeed.

    Raises:
        ToolchainError: no ancestor of *start* is a hejmark checkout.
    """
    for directory in [start.resolve(), *start.resolve().parents]:
        if (directory / "pyproject.toml").is_file() and (directory / "rust").is_dir():
            return directory
    msg = f"{start} is not inside a hejmark checkout (needs pyproject.toml beside rust/)"
    raise ToolchainError(msg)


class ToolchainBuilder:
    """Runs the engine build steps a Flutter bundle is assembled over."""

    def steps(self, root: Path, *, host_only: bool) -> tuple[Step, ...]:
        """The steps to run under *root*, in order.

        The debug binaries come first because they are what a desktop run uses
        (``rust/target/debug/{find,run}``, the subprocess path's engine), and
        the shared library second because it is what the *app* loads. With
        *host_only* the second skips the Android cross-compile, which is the
        difference between needing the NDK and not.
        """
        engine = root / "gui" / "tool" / "build_engine.sh"
        arguments = ("--host-only",) if host_only else ()
        return (
            Step("engine binaries (debug)", ("cargo", "build"), root / "rust"),
            Step("engine library (release)", (str(engine), *arguments), root),
        )

    def run(self, step: Step) -> None:
        """Run one *step*, raising rather than returning a code.

        Raises:
            ToolchainError: the tool is not installed, or it exited non-zero.
                Either way the message names the step, so a failure half way
                through a build says which half.
        """
        try:
            result = subprocess.run(  # noqa: S603
                list(step.argv),
                capture_output=True,
                text=True,
                cwd=step.cwd,
                check=False,
            )
        except (FileNotFoundError, PermissionError) as exc:
            msg = f"{step.name}: cannot run {step.argv[0]} ({exc})"
            raise ToolchainError(msg) from exc
        if result.returncode != 0:
            msg = (
                f"{step.name}: {step.argv[0]} failed (exit {result.returncode}):\n"
                f"{result.stdout}{result.stderr}"
            )
            raise ToolchainError(msg)
