"""core: pure business logic and the port interfaces.

No I/O and no imports from adapters -- the import-linter contract guarantees
this. Depends only on lib. Cross-layer interfaces are declared as Protocols in
core.ports.
"""

from __future__ import annotations
