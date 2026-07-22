"""Render the Himark Editor icon for every platform that shows one.

Pure standard library -- no Pillow, no ImageMagick, no cairosvg -- so the icon
is reproducible from a checkout with nothing but Python. The artwork is the
"{h|" mark: an open brace, an italic h, and a serif I-beam, transcribed
verbatim -- path data, transforms, stroke widths -- from its 20x20 source SVG.
Unlike the "{Hi}" mark this replaced, the source has real curves (the brace,
the h's bowl), so `svgpath` parses the actual path data rather than
approximating everything as straight capsules: its polylines feed the
rasteriser, and the same parsed curves feed Android's vector drawables
unflattened.

    python3 tool/make_icons.py

writes every output from that one geometry: the Android launcher resources, the
whole iOS AppIcon.appiconset, the F-Droid listing PNG, and the freedesktop icon
theme and desktop entry Linux wants. This module owns the mark, the placements
and the rasteriser; each target wanting more than a PNG has its own serialiser
beside it -- `android.py`, `freedesktop.py` -- taking marks already placed and
choosing only attribute names. `svgpath.py` is the other end of that split,
knowing shapes and no targets at all.

Two placements share the paths. **Full-bleed** carries the mark on the source's
own 20-unit canvas, inset by FULL_INSET -- used for iOS, which masks its own
corners so the asset must be an edge-to-edge square, and for the legacy/F-Droid
renders, which draw the rounded square themselves because nothing out there
supplies one. **Adaptive** is a second, smaller placement for Android's
adaptive icon: a launcher may crop the 108-unit foreground to anything from a
circle to a square but guarantees a centred 66-unit circle survives, so the
mark is scaled until its own farthest inked point sits at SAFE_RADIUS.

Both placements centre the mark's *ink*, not the canvas: the source art carries
about a unit more air on its right than its left, which a round mask makes
obvious. Only iOS and F-Droid take PNG; the Android drawables stay vector.
"""

import json
import math
import struct
import zlib
from pathlib import Path

import android
import freedesktop
import svgpath

ROOT = Path(__file__).resolve().parent.parent
CANVAS = 1024.0
DESIGN = 20.0  # the source SVG's own viewBox
BG = (0x28, 0x28, 0x28)
FG = (0xFF, 0xFF, 0xFF)
BG_RADIUS = CANVAS * 0.2
SAMPLES = 3
LISTING_SIZE = 512

# Transcribed verbatim from the source SVG: (path data, own transform as an
# (a,b,c,d,e,f) matrix, stroke width or None for a fill).
_I_BEAM = ("M1 10L0 10L0 1L-1 1M1 1L0 1L0 10L-1 10", (1, 0, 0, 1.35, 16.2188, 2.25977), 0.75)
_H = (
    "M2.254 7.744L1.611 11.62L0.3218 11.62L1.769 2.895L3.047 2.895L2.418 6.678"
    "L2.249 6.678C2.444 6.282 2.66 5.96 2.898 5.712C3.135 5.465 3.397 5.283 "
    "3.682 5.167C3.968 5.05 4.28 4.992 4.618 4.992C5.063 4.992 5.443 5.086 "
    "5.757 5.273C6.072 5.459 6.297 5.736 6.433 6.102C6.569 6.469 6.592 6.922 "
    "6.501 7.463L5.81 11.62L4.516 11.62L5.183 7.623C5.263 7.145 5.2 6.774 "
    "4.993 6.51C4.786 6.246 4.47 6.114 4.045 6.114C3.758 6.114 3.489 6.178 "
    "3.238 6.305C2.987 6.432 2.775 6.616 2.601 6.857C2.427 7.098 2.311 7.393 "
    "2.254 7.744Z",
    (1, 0, 0, 1, 6, 3),
    None,
)
_BRACE = (
    "M2 -5C2 -5 1 -5 1 -4C1 -3 1 -1 1 -1L0 0L1 1C1 1 1 3 1 4C1 5 2 5 2 5",
    (1, 0, 0, 1, 2, 10.2598),
    1.0,
)
_SHAPES = (_I_BEAM, _H, _BRACE)


def _design_ink():
    """The mark's inked bounds in design units, stroke width included."""
    boxes = []
    for d, xf, width in _SHAPES:
        pad = 0.0 if width is None else width / 2
        pts = [p for line in svgpath.flatten(svgpath.place(svgpath.parse(d), xf)) for p in line]
        boxes.append(svgpath.bounds(pts, pad))
    return svgpath.union(boxes)


INK = _design_ink()
_CX, _CY = (INK[0] + INK[2]) / 2, (INK[1] + INK[3]) / 2
# Farthest inked point from that centre: the radius a launcher mask must spare.
_EXTENT = max(
    math.hypot(x - _CX, y - _CY) + (0.0 if width is None else width / 2)
    for d, xf, width in _SHAPES
    for line in svgpath.flatten(svgpath.place(svgpath.parse(d), xf))
    for x, y in line
)

# A full-bleed icon is masked to a rounded square by whoever shows it, so the
# mark is inset rather than filling the canvas: at 1.0 the art spans 80% of the
# width and crowds the corner curve, which reads as cramped at every size. 0.84
# puts it near 68%, the usual weight for a glyph mark.
FULL_INSET = 0.84
FULL_SCALE = CANVAS / DESIGN * FULL_INSET
# Android guarantees only that a centred 66-unit circle of the 108-unit
# foreground survives cropping, so the mark's extent is scaled to this radius.
# 28 rather than the full 33 is the margin: masks vary, and a glyph touching
# the guarantee looks wedged into it even where nothing is actually cut.
SAFE_RADIUS = 28.0
ADAPTIVE_SCALE = SAFE_RADIUS / _EXTENT


def _centred(scale, target):
    """Place the design at `scale`, with its ink centred on (target, target)."""
    return (scale, 0.0, 0.0, scale, target - _CX * scale, target - _CY * scale)


def _hex(colour):
    """An (r, g, b) triple as the #RRGGBB every serialiser downstream wants."""
    return f"#{colour[0]:02X}{colour[1]:02X}{colour[2]:02X}"


def _capsule_covers(px, py, cap):
    """Is (px, py) inside the capsule? Distance from point to segment."""
    x1, y1, x2, y2, radius = cap
    dx, dy = x2 - x1, y2 - y1
    span = dx * dx + dy * dy
    t = 0.0 if span == 0 else ((px - x1) * dx + (py - y1) * dy) / span
    t = max(0.0, min(1.0, t))
    ox, oy = px - (x1 + t * dx), py - (y1 + t * dy)
    return ox * ox + oy * oy <= radius * radius


def _rounded_square_covers(px, py, size, radius):
    """Is (px, py) inside a rounded square of this size? radius 0 is a square."""
    qx = abs(px - size / 2) - (size / 2 - radius)
    qy = abs(py - size / 2) - (size / 2 - radius)
    if qx <= 0 or qy <= 0:
        # Off an edge, not a corner: only the overshooting axis constrains it.
        return max(qx, qy) <= radius
    return qx * qx + qy * qy <= radius * radius


def _polygon_covers(px, py, poly):
    """Ray-cast point-in-polygon; callers bbox-gate before reaching this."""
    inside = False
    lx, ly = poly[-1]
    for x, y in poly:
        if (ly > py) != (y > py) and px < lx + (py - ly) * (x - lx) / (y - ly):
            inside = not inside
        lx, ly = x, y
    return inside


def _raster_geometry():
    """Fills and capsules in CANVAS space, each with its own gating bbox.

    Every shape is the same colour, so the rasteriser only asks *whether* a
    sample is inked, never by which shape -- which is what lets `_inked` stop
    at the first hit instead of resolving a painter's-algorithm stack.
    """
    at = _centred(FULL_SCALE, CANVAS / 2)
    fills, capsules = [], []
    for d, xf, width in _SHAPES:
        lines = svgpath.flatten(svgpath.place(svgpath.parse(d), svgpath.compose(at, xf)))
        if width is None:
            fills.extend((poly, svgpath.bounds(poly)) for poly in lines)
        else:
            r = width / 2 * FULL_SCALE
            capsules.extend(
                (cap, svgpath.bounds(((cap[0], cap[1]), (cap[2], cap[3])), r))
                for cap in svgpath.capsules_along(lines, r)
            )
    return fills, capsules, svgpath.union([b for _, b in (*fills, *capsules)])


FILLS, CAPSULES, INK_BOUNDS = _raster_geometry()


def _inked(px, py):
    """Is this sample on the mark? First hit wins; the mark is one colour."""
    x0, y0, x1, y1 = INK_BOUNDS
    if not (x0 <= px <= x1 and y0 <= py <= y1):
        return False
    for poly, (bx0, by0, bx1, by1) in FILLS:
        if bx0 <= px <= bx1 and by0 <= py <= by1 and _polygon_covers(px, py, poly):
            return True
    for cap, (bx0, by0, bx1, by1) in CAPSULES:
        if bx0 <= px <= bx1 and by0 <= py <= by1 and _capsule_covers(px, py, cap):
            return True
    return False


def render(size, bg_mode):
    """Render at `size` px, returning RGBA rows. bg_mode "square" is a plain
    full-bleed background (iOS masks its own corners); "rounded" draws the
    corner this project supplies itself (Android legacy/F-Droid have none)."""
    scale = CANVAS / size
    radius = 0.0 if bg_mode == "square" else BG_RADIUS / scale
    offsets = [(k + 0.5) / SAMPLES for k in range(SAMPLES)]
    total = SAMPLES * SAMPLES
    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            covered = ink = 0
            for dy in offsets:
                for dx in offsets:
                    px, py = x + dx, y + dy
                    if not _rounded_square_covers(px, py, size, radius):
                        continue
                    covered += 1
                    ink += _inked(px * scale, py * scale)
            if covered == 0:
                row += b"\x00\x00\x00\x00"
            else:
                # Colour is the ink/background mix over the samples that landed
                # on the icon; alpha is only the corner cut. They average apart.
                mix = ink / covered
                rgb = tuple(round(BG[i] + (FG[i] - BG[i]) * mix) for i in range(3))
                row += bytes((*rgb, round(covered / total * 255)))
        rows.append(bytes(row))
    return rows


def write_png(path, rows, *, alpha=True):
    """Write RGBA rows as a PNG; alpha=False drops the channel, which is what
    the App Store wants -- it rejects an icon carrying one even fully opaque."""
    width, height = len(rows[0]) // 4, len(rows)
    if alpha:
        raw = b"".join(b"\x00" + row for row in rows)
        colour_type = 6
    else:
        raw = b"".join(
            b"\x00" + b"".join(row[i : i + 3] for i in range(0, len(row), 4)) for row in rows
        )
        colour_type = 2

    def chunk(tag, payload):
        head = struct.pack(">I", len(payload)) + tag
        return head + payload + struct.pack(">I", zlib.crc32(tag + payload))

    header = struct.pack(">IIBBBBB", width, height, 8, colour_type, 0, 0, 0)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def _elements(at):
    """The mark's three elements at `at`, as (path data, stroke width or None).

    The data is the same M/L/C string a VectorDrawable and an SVG both read, so
    a caller downstream chooses attribute names and never geometry. Placing the
    stroke width here rather than leaving `at` to be reapplied is what keeps the
    two serialisers from having to agree about scale as well as shape.
    """
    return [
        (
            svgpath.serialise(
                svgpath.place(svgpath.parse(d), svgpath.compose(at, xf)), close=w is None
            ),
            None if w is None else w * at[0],
        )
        for d, xf, w in _SHAPES
    ]


def android_resources():
    """The three generated Android resources, as (path under res/, text) pairs.

    Both placements are resolved here because this is the half that owns
    geometry: `android.py` chooses attribute names and never scale. The
    adaptive foreground is the small placement, the legacy drawable the
    full-bleed one -- see `android.py` for which API level reads which.
    """
    full = _elements(_centred(FULL_SCALE, CANVAS / 2))
    adaptive = _elements(_centred(ADAPTIVE_SCALE, android.VIEWPORT / 2))
    return (
        ("mipmap/ic_launcher.xml", android.legacy(full, CANVAS, BG_RADIUS, _hex(BG), _hex(FG))),
        ("drawable/ic_launcher_foreground.xml", android.foreground(adaptive, _hex(FG))),
        ("values/ic_launcher_background.xml", android.background_color(_hex(BG))),
    )


def freedesktop_share():
    """The Linux desktop's icon theme and desktop entry, as an installable tree.

    Linux masks nothing and supplies no corner, so this is the full-bleed
    placement over the rounded square the launcher render already draws -- the
    Android legacy drawable's twin, in the two forms freedesktop's specs ask
    for. What is written where, and why the name is spelled three times, is
    `freedesktop.py`.
    """
    svg = freedesktop.svg_document(
        _elements(_centred(FULL_SCALE, CANVAS / 2)), CANVAS, BG_RADIUS, _hex(BG), _hex(FG)
    )
    return freedesktop.write_share(
        ROOT / "linux/packaging/share",
        svg,
        lambda size, path: write_png(path, render(size, "rounded")),
    )


def ios_icon_set():
    """Render every slot the appiconset's own Contents.json declares.

    The manifest is the source of truth for which sizes exist, so adding a slot
    in Xcode is enough -- there is no second list here to fall out of step.
    """
    appiconset = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    manifest = json.loads((appiconset / "Contents.json").read_text())
    for image in manifest["images"]:
        px = round(float(image["size"].split("x")[0]) * int(image["scale"].rstrip("x")))
        write_png(appiconset / image["filename"], render(px, "square"), alpha=False)
    return len(manifest["images"])


def main():
    res = ROOT / "android/app/src/main/res"
    for rel, text in android_resources():
        (res / rel).parent.mkdir(parents=True, exist_ok=True)
        (res / rel).write_text(text)
    listing = ROOT / "fastlane/metadata/android/en-US/images/icon.png"
    write_png(listing, render(LISTING_SIZE, "rounded"))
    count = ios_icon_set()
    shared = freedesktop_share()
    print(
        f"wrote 3 Android resources, {listing.name}, {count} iOS icon slots, "
        f"and {shared} freedesktop files"
    )


if __name__ == "__main__":
    main()
