#!/usr/bin/env bash
# Stage the Python compiler into the Android app, for Chaquopy to package.
#
# The app embeds CPython so a phone can run the *real* compiler -- ANTLR parse,
# L1.5 expansion, floor-AST JSON out -- rather than the floor subset
# `rust/src/surface/parse.rs` reads. Chaquopy packages whatever sits under
# `android/app/src/main/python/`, so `<root>/hejmark` has to be copied there.
#
# Copied rather than symlinked: Gradle hashes the source tree to decide what to
# rebuild, and a symlink makes that hash blind to edits behind it.
#
# Like the engine's `.so` files, the staged copy is generated and gitignored --
# F-Droid builds from source, and a vendored second copy of the package would be
# both stale and confusing. Re-run this after touching `hejmark/`.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
gui=$(dirname "$here")
root=$(dirname "$gui")
dest="$gui/android/app/src/main/python/hejmark"

# The ANTLR parser is generated too (`hejmark/adapters/_gen`, gitignored), and
# without it the staged package imports nothing. Generating it needs the antlr4
# tool, which is why this is a check with a message rather than a silent build.
if [ ! -f "$root/hejmark/adapters/_gen/HimarkParser.py" ]; then
    echo "generating the ANTLR parser first" >&2
    (cd "$root" && uv run hejmark gen-parser)
fi

rm -rf "$dest"
mkdir -p "$(dirname "$dest")"
cp -r "$root/hejmark" "$dest"

# The CLI layer is the one part the device has no use for, and the only part
# that costs a dependency: `typer` is imported from `cli/` and nowhere else, so
# dropping the layer is what keeps the on-device requirement list at one pure
# Python wheel. `__main__.py` goes with it -- it is the CLI's entry point.
rm -rf "$dest/cli" "$dest/__main__.py"
find "$dest" -name __pycache__ -type d -prune -exec rm -rf {} +

echo "staged $(find "$dest" -name '*.py' | wc -l) modules into ${dest#"$root"/}"
