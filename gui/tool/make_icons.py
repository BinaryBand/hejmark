"""Render the Himark Editor launcher icon.

Pure standard library -- no Pillow, no ImageMagick -- so the icon is
reproducible from a checkout with nothing but Python. The artwork is the
"slate" mark (see docs/.notes/icons/slate.svg): a "{Hi}" wordmark on a
rounded square, built from round-capped capsules -- straight strokes for H
and i, and each brace approximated as a four-segment zigzag since capsules
have no curves.

Geometry is written once, in a 1024x1024 canvas, and shared by every output:

    python3 tool/make_icons.py

    android/app/src/main/res/mipmap/ic_launcher.xml     legacy, full icon
    android/app/src/main/res/drawable/ic_launcher_foreground.xml  adaptive
    fastlane/metadata/android/en-US/images/icon.png     F-Droid listing

The two launcher drawables are both vectors, and which one a device reads is
decided by resource qualifiers alone: API 26 and up resolve `@mipmap/ic_launcher`
to `mipmap-anydpi-v26/ic_launcher.xml`, the adaptive icon whose foreground is the
capsules scaled to the 108-unit viewport (their furthest points sit inside a
~26-unit radius of centre, well within the ~33-36-unit safe circle, so no
launcher mask clips them); API 24-25 fall through to the unqualified
`mipmap/ic_launcher.xml`, which is the whole mark -- rounded-square background
included, since there is no mask out there to supply one. VectorDrawable is
native from API 21, so the floor this project already sets (minSdk 24) is clear.

Only the F-Droid listing is a raster, because that catalogue takes PNG.
"""

import struct
import zlib
from pathlib import Path

CANVAS = 1024.0
BG = (0x2B, 0x2F, 0x38)
BG_RADIUS = 205.0
FG = (0xC7, 0xCD, 0xD9)

# (x1, y1, x2, y2, radius, colour) -- centrelines, drawn back to front.
# "{Hi}", left to right, baseline-aligned on y 340-660:
CAPSULES = [
    # opening brace
    (317.0, 340.0, 287.0, 410.0, 28.0, FG),
    (287.0, 410.0, 267.0, 500.0, 28.0, FG),
    (267.0, 500.0, 287.0, 590.0, 28.0, FG),
    (287.0, 590.0, 317.0, 660.0, 28.0, FG),
    # H
    (397.0, 340.0, 397.0, 660.0, 34.0, FG),
    (527.0, 340.0, 527.0, 660.0, 34.0, FG),
    (397.0, 500.0, 527.0, 500.0, 30.0, FG),
    # i (dot is a degenerate capsule -- equal endpoints render as a circle)
    (627.0, 380.0, 627.0, 380.0, 34.0, FG),
    (627.0, 460.0, 627.0, 660.0, 30.0, FG),
    # closing brace
    (707.0, 340.0, 737.0, 410.0, 28.0, FG),
    (737.0, 410.0, 757.0, 500.0, 28.0, FG),
    (757.0, 500.0, 737.0, 590.0, 28.0, FG),
    (737.0, 590.0, 707.0, 660.0, 28.0, FG),
]

ROOT = Path(__file__).resolve().parent.parent
LISTING_SIZE = 512
SAMPLES = 3


def _capsule_covers(px, py, cap):
    """Is (px, py) inside the capsule? Distance from point to segment."""
    x1, y1, x2, y2, radius, _ = cap
    dx, dy = x2 - x1, y2 - y1
    span = dx * dx + dy * dy
    t = 0.0 if span == 0 else ((px - x1) * dx + (py - y1) * dy) / span
    t = max(0.0, min(1.0, t))
    ox, oy = px - (x1 + t * dx), py - (y1 + t * dy)
    return ox * ox + oy * oy <= radius * radius


def _rounded_square_covers(px, py, size, radius):
    """Is (px, py) inside a rounded square of the given size?"""
    qx = abs(px - size / 2) - (size / 2 - radius)
    qy = abs(py - size / 2) - (size / 2 - radius)
    if qx <= 0 or qy <= 0:
        # Off a corner: only the axis that overshoots constrains the point.
        return max(qx, qy) <= radius
    return qx * qx + qy * qy <= radius * radius


def render(size, background):
    """Render the icon at `size` px, returning RGBA rows."""
    scale = CANVAS / size
    radius = BG_RADIUS / scale
    step = 1.0 / SAMPLES
    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            r = g = b = a = 0.0
            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    px, py = x + (sx + 0.5) * step, y + (sy + 0.5) * step
                    if background and not _rounded_square_covers(px, py, size, radius):
                        continue
                    hit = BG if background else None
                    for cap in CAPSULES:
                        if _capsule_covers(px * scale, py * scale, cap):
                            hit = cap[5]
                    if hit is None:
                        continue
                    r, g, b, a = r + hit[0], g + hit[1], b + hit[2], a + 1.0
            if a == 0:
                row += b"\x00\x00\x00\x00"
            else:
                cover = a / (SAMPLES * SAMPLES)
                row += bytes((round(r / a), round(g / a), round(b / a), round(cover * 255)))
        rows.append(bytes(row))
    return rows


def write_png(path, rows):
    """Write RGBA rows as a PNG."""
    raw = b"".join(b"\x00" + row for row in rows)
    width, height = len(rows[0]) // 4, len(rows)

    def chunk(tag, payload):
        head = struct.pack(">I", len(payload)) + tag
        return head + payload + struct.pack(">I", zlib.crc32(tag + payload))

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def _capsule_paths(unit):
    """The capsules as <path> elements, scaled by `unit` per canvas unit.

    A capsule whose endpoints coincide (the "i" dot) is emitted as a filled circle
    rather than a zero-length round-capped stroke: the stroke is the same shape in
    principle, but a zero-length subpath is exactly what a path renderer is free to
    drop, and losing it would silently take the dot off the "i".
    """
    paths = []
    for x1, y1, x2, y2, radius, colour in CAPSULES:
        hexed = f"#{colour[0]:02X}{colour[1]:02X}{colour[2]:02X}"
        sx, sy, ex, ey = x1 * unit, y1 * unit, x2 * unit, y2 * unit
        r = radius * unit
        if (sx, sy) == (ex, ey):
            paths.append(
                "    <path\n"
                f'        android:pathData="M{sx - r:.2f},{sy:.2f} '
                f"a{r:.2f},{r:.2f} 0 1 0 {2 * r:.2f},0 "
                f'a{r:.2f},{r:.2f} 0 1 0 {-2 * r:.2f},0 Z"\n'
                f'        android:fillColor="{hexed}" />'
            )
            continue
        paths.append(
            "    <path\n"
            f'        android:pathData="M{sx:.2f},{sy:.2f} L{ex:.2f},{ey:.2f}"\n'
            f'        android:strokeColor="{hexed}"\n'
            f'        android:strokeWidth="{2 * r:.2f}"\n'
            '        android:strokeLineCap="round" />'
        )
    return paths


def _vector(size, viewport, body):
    """Wrap `body` in a square <vector> of `size` dp over a `viewport`-unit grid."""
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        # No "--" in the comment: aapt2 rejects it.
        "<!-- Generated by tool/make_icons.py; edit the geometry there. -->\n"
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        f'    android:width="{size:g}dp"\n'
        f'    android:height="{size:g}dp"\n'
        f'    android:viewportWidth="{viewport:g}"\n'
        f'    android:viewportHeight="{viewport:g}">\n'
        f"{body}\n"
        "</vector>\n"
    )


def foreground_vector():
    """The capsules as an adaptive-icon foreground drawable."""
    return _vector(108.0, 108.0, "\n".join(_capsule_paths(108.0 / CANVAS)))


def legacy_vector():
    """The whole mark -- background included -- for API 24-25, which has no mask.

    Drawn straight in the 1024-unit canvas, so the geometry needs no scaling; the
    48dp is only the size a launcher asks a legacy icon for, and the viewport
    carries the artwork at whatever density it is then rasterised to.
    """
    r = BG_RADIUS
    end = CANVAS - r
    background = (
        "    <path\n"
        f'        android:pathData="M{r:.0f},0 H{end:.0f} '
        f"A{r:.0f},{r:.0f} 0 0 1 {CANVAS:.0f},{r:.0f} V{end:.0f} "
        f"A{r:.0f},{r:.0f} 0 0 1 {end:.0f},{CANVAS:.0f} H{r:.0f} "
        f"A{r:.0f},{r:.0f} 0 0 1 0,{end:.0f} V{r:.0f} "
        f'A{r:.0f},{r:.0f} 0 0 1 {r:.0f},0 Z"\n'
        f'        android:fillColor="#{BG[0]:02X}{BG[1]:02X}{BG[2]:02X}" />'
    )
    return _vector(48.0, CANVAS, "\n".join([background, *_capsule_paths(1.0)]))


def main():
    res = ROOT / "android/app/src/main/res"
    legacy = res / "mipmap/ic_launcher.xml"
    legacy.parent.mkdir(parents=True, exist_ok=True)
    legacy.write_text(legacy_vector())
    (res / "drawable/ic_launcher_foreground.xml").write_text(foreground_vector())
    listing = ROOT / "fastlane/metadata/android/en-US/images/icon.png"
    write_png(listing, render(LISTING_SIZE, True))
    print(f"wrote the legacy and adaptive launcher vectors and {listing.name}")


if __name__ == "__main__":
    main()
