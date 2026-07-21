"""The wrap ceiling: how many entries a universe carries, as a modulus.

Groundwork the render layer will read, not yet consumed here. A positional
value drawn from a universe wraps against the count of entries it carries --
``{0..9}`` is base ten, and a width-``w`` field of it ceils at ``ten ** w`` --
so an arithmetic that overflows a field folds back modulo that ceiling. This
module computes the ceiling structurally, without streaming a single entry, so
an astronomically wide field costs nothing to price.

The count is exact only where it can be: a universe built from disjoint faces
and ranges, and products of such, has a ceiling this returns exactly. Anywhere
+the collision rule might drop an entry (overlapping members, a subtraction) or
+a member is unbounded (a final segment, a closure), it returns ``None`` -- "no
+known ceiling", never a wrong one. A later refinement may price more shapes;
+none may return a count that streaming the entries would contradict.
"""