"""core: pure business logic and the port interfaces.

No I/O and no imports from adapters -- the import-linter contract guarantees
this. Depends only on utils. Cross-layer interfaces are declared as Protocols in
core.ports. This package is a namespace shell -- logic lives in modules like
core.main.
"""

from __future__ import annotations
