"""core.scan: matching a denoted universe against a target document.

`match` walks a target and yields spans; `capture` resolves a match back to the
entry wearing it, which is the bounded read `$0` depends on. Both sit above the
floor and below the use-cases in `core.engine` / `core.emit`.
"""

from __future__ import annotations
