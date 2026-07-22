"""Enough SVG path geometry to render one icon, in the standard library alone.

`make_icons.py` is the only caller; this half is the part that knows nothing
about the mark, the launchers, or the outputs -- just absolute M/L/C paths,
affine transforms, and the polylines a rasteriser needs. Kept separate because
the two halves answer different questions ("what shape is this?" versus "what
does each platform want?") and because neither needs anything from the other:
the dependency runs one way, so there is no cycle to reason about.

Only the absolute M, L, C and Z commands appear in the source artwork, so only
those are handled. A path using anything else would parse into nonsense rather
than raise, which is a real limitation and the reason the artwork is
transcribed into `make_icons.py` verbatim rather than read from an SVG file at
run time -- what is committed is what was checked.
"""

import itertools
import re
from typing import NamedTuple


class Subpath(NamedTuple):
    """One M-started run: where it begins, then the segments after it.

    A pair rather than a dict because the two fields have different types and
    only one of them is appended to -- which a dict of mixed value types cannot
    express, and a type checker rightly refuses to assume.
    """

    start: tuple[float, float]
    segs: list[tuple]


def parse(d):
    """An absolute M/L/C path as Subpaths of ('L',x,y) / ('C',x1,y1,x2,y2,x,y)."""
    tokens = re.findall(r"[MLCZ]|-?\d*\.?\d+(?:[eE][-+]?\d+)?", d)
    subpaths: list[Subpath] = []
    cmd, i = None, 0
    while i < len(tokens):
        if tokens[i] in "MLCZ":
            cmd, i = tokens[i], i + 1
            if cmd == "Z":
                continue
        if cmd == "M":
            subpaths.append(Subpath((float(tokens[i]), float(tokens[i + 1])), []))
            # Bare coordinate pairs after an M are implicit linetos, not moves.
            i, cmd = i + 2, "L"
        elif cmd == "L":
            subpaths[-1].segs.append(("L", float(tokens[i]), float(tokens[i + 1])))
            i += 2
        else:
            subpaths[-1].segs.append(("C", *(float(v) for v in tokens[i : i + 6])))
            i += 6
    return subpaths


def apply_to(xf, x, y):
    """One point through an (a,b,c,d,e,f) affine."""
    a, b, c, d, e, f = xf
    return a * x + c * y + e, b * x + d * y + f


def compose(m2, m1):
    """m2-after-m1, as one affine: apply m1's transform, then m2's."""
    a1, b1, c1, d1, e1, f1 = m1
    a2, b2, c2, d2, e2, f2 = m2
    return (
        a2 * a1 + c2 * b1,
        b2 * a1 + d2 * b1,
        a2 * c1 + c2 * d1,
        b2 * c1 + d2 * d1,
        a2 * e1 + c2 * f1 + e2,
        b2 * e1 + d2 * f1 + f2,
    )


def place(subpaths, xf):
    """Every point of every subpath through one affine."""
    out = []
    for sp in subpaths:
        segs = []
        for seg in sp.segs:
            if seg[0] == "L":
                segs.append(("L", *apply_to(xf, seg[1], seg[2])))
            else:
                p = [apply_to(xf, seg[i], seg[i + 1]) for i in (1, 3, 5)]
                segs.append(("C", *p[0], *p[1], *p[2]))
        out.append(Subpath(apply_to(xf, *sp.start), segs))
    return out


def flatten(subpaths, n=24):
    """Subpaths, curves included, as polylines -- for the rasteriser only.

    The Android drawables keep the curves; only pixels need them straightened,
    so `n` trades render cost against a faceting error that is invisible well
    before the icon's largest raster size.
    """
    polylines = []
    for sp in subpaths:
        cx, cy = sp.start
        pts = [(cx, cy)]
        for seg in sp.segs:
            if seg[0] == "L":
                cx, cy = seg[1], seg[2]
                pts.append((cx, cy))
            else:
                _, x1, y1, x2, y2, x3, y3 = seg
                for k in range(1, n + 1):
                    t = k / n
                    m = 1 - t
                    pts.append(
                        (
                            m**3 * cx + 3 * m**2 * t * x1 + 3 * m * t**2 * x2 + t**3 * x3,
                            m**3 * cy + 3 * m**2 * t * y1 + 3 * m * t**2 * y2 + t**3 * y3,
                        )
                    )
                cx, cy = x3, y3
        polylines.append(pts)
    return polylines


def bounds(points, pad=0.0):
    """Bounding box of some points, grown by `pad` (a stroke's half-width)."""
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad


def union(boxes):
    """The one box covering them all."""
    cols = list(zip(*boxes, strict=True))
    return min(cols[0]), min(cols[1]), max(cols[2]), max(cols[3])


def serialise(subpaths, *, close):
    """Subpaths back to path data -- `parse`'s inverse, to two decimals.

    One spelling serves every vector output the project has, because Android's
    VectorDrawable pathData is SVG path syntax. `close` emits the source's Z: a
    fill closes implicitly anyway, a stroke does not, so it is said outright.
    """
    parts = []
    for sp in subpaths:
        parts.append(f"M{sp.start[0]:.2f},{sp.start[1]:.2f}")
        for seg in sp.segs:
            if seg[0] == "L":
                parts.append(f"L{seg[1]:.2f},{seg[2]:.2f}")
            else:
                parts.append(
                    f"C{seg[1]:.2f},{seg[2]:.2f} {seg[3]:.2f},{seg[4]:.2f} "
                    f"{seg[5]:.2f},{seg[6]:.2f}"
                )
        if close:
            parts.append("Z")
    return " ".join(parts)


def capsules_along(polylines, radius):
    """A flattened polyline as round-capped capsules, joint to joint.

    A round cap at every joint is what makes this equal a round-joined stroke:
    consecutive capsules overlap on a disc of the same radius, so the seam a
    mitre would show cannot appear.
    """
    return [
        (x1, y1, x2, y2, radius)
        for pts in polylines
        for (x1, y1), (x2, y2) in itertools.pairwise(pts)
    ]
