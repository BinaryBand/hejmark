"""core.floor: the L1 denotational core -- five constructors and nothing else.

`syntax` is the AST expansion targets, `universe` denotes it, `order` supplies
the iteration order the denotation is defined against. Nothing here knows that
L1.5 exists, and the import-linter "core pipeline" contract keeps it that way:
this is the bottom layer, so it may not import `surface`, `scan`, or anything
above them. That is L1.5's admission rule ("a construct expands into the five
constructors or it does not enter") made structural.
"""

from __future__ import annotations
