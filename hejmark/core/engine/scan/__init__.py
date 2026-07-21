"""engine.scan: matching a denoted universe against a target document.

`match` walks a target and yields spans; `capture` resolves a match back to the
entry wearing it, which is the bounded read `$0` depends on. Both sit above the
floor and below the executor in `core.engine.execute`.
"""

from __future__ import annotations
