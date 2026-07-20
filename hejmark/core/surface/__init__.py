"""core.surface: L1.5, the layer that rewrites itself away.

`ast` is the surface AST (the floor's nodes plus refs, units, declarations,
statements, templates), `resolve` binds names, and `expand` rewrites the whole
tree down to `core.floor.syntax`. Expansion's output type is the floor's, which
is why the floor never needs to import back up.
"""

from __future__ import annotations
