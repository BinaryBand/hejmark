# Himark Editor — Flutter GUI

A Flutter front end for the **Himark Editor** described in
`docs/.notes/Himark Editor.zip` (design brief + screenshots).

The Test tab is wired to the **real hejmark engines** — never to a `RegExp`
approximation. Matching is the actual denotation and the actual matcher, or a
reported error. "Saving…" is still a cosmetic flash and project data lives in
memory for the session.

## Engine bridge

`lib/models/bridge.dart` (`HejmarkBridge`) carries both of the language's verbs
— `find` highlights where rules hit, `run` executes them as a script and
returns the rewritten document — over two paths that differ only in **where
the compiler runs**. Both compile all of L1.5, and the engine is the same Rust
either way. `lib/models/backend.dart` is where that shows: a `Compiler` lowers
source to a program (`emit-json` for one rule, `emit-program` for a whole
script), an `Engine` runs programs over text (`findAll` to spans, `run` to a
document), and a `Backend` is one of each.

```text
embedded    rule.source ──emit-json (embedded python)──▶ floor JSON ──┐
subprocess  rule.source ──emit-json (python subprocess)─▶ floor JSON ─┤
                                     libhejmark.so / find (rust) ◀────┘──▶ spans
embedded    script ──emit-program (embedded python)──▶ Program JSON ──┐
subprocess  script ──emit-program (python subprocess)─▶ Program JSON ─┤
                                      libhejmark.so / run (rust) ◀────┘──▶ document
```

**Embedded** (`lib/models/embedded_backend.dart`, Android) is the phone's whole
answer. Chaquopy embeds CPython in the APK, so the repository's *real* compiler
— ANTLR parser, L1.5 expansion, `emit_json` — runs on the device and emits the
same floor-AST JSON the desktop emits. The program then goes to
`hejmark_find_json` in `libhejmark.so`, linked beside it (`<root>/rust` built as
a C-ABI shared library, `rust/src/ffi.rs`): the compiler moved onto the device,
the engine never left Rust. Dart reaches the compiler over a MethodChannel
(`android/.../MainActivity.kt`), because there is no C ABI to a Python
interpreter.

**Subprocess** is the same hand-off with the compiler in another process:
`<root>/.venv/bin/python -m hejmark emit-json` into `<root>/rust/target/debug/
find`. A **desktop-inside-a-checkout** capability.

There used to be a third: the Rust library parsing a *subset* of Himark for
itself, so a phone had something without an interpreter. Embedding CPython made
it strictly worse than what stood beside it, and it is gone — `rust/` now parses
no Himark at all and takes only compiled programs. What that costs is a platform
neither backend reaches: **iOS**, and a packaged Linux build outside a checkout.
Those report `engine unavailable`, as a machine with nothing installed always
did.

- Build the device engine with `./tool/build_engine.sh` before running or
  packaging, and generate the ANTLR parser once with `uv run hejmark gen-parser`
  in the repository root. Neither output is committed — F-Droid builds from
  source and rejects prebuilt binaries — so an APK built without them ships no
  engine and no compiler. The Gradle build fails loudly on a missing parser; a
  missing engine it cannot see.
- The compiler is **not copied into this tree**. `android/app/src/main/python/
  hejmark` is a committed symlink to `<root>/hejmark`, so Chaquopy packages the
  real source tree and an edit there is on the device at the next build. Gradle
  follows the link for its up-to-date check, which was the one thing worth
  verifying before trusting it.
- Embedding CPython costs about **13.7 MB per ABI** (interpreter, stdlib, and
  the one pure-Python dependency `antlr4-python3-runtime`). `typer` does not
  ship: it is imported from `hejmark/cli/` and nothing on the device imports
  that, so the package's own dependency does not become the app's.
- Every `Compiler` caches per rule source, refusals included, so a rule is
  compiled only when edited.
- The Rust matcher's maximal-munch does not terminate on an unbounded closure
  (a bare `{X,&X}` Kleene star), so both paths run under a time budget and a
  pattern that blows it shows `pattern too complex`. The device path also runs
  on a background isolate, so a slow rule costs a slow result rather than a
  frozen frame. The seeded rules (IPv4, hex colour, 4-digit number) are all
  bounded spellings the engine settles on quickly.

Widget tests inject a synchronous `Bridge` fake (`test/fake_bridge.dart`) so
flows stay deterministic without any engine — it answers per rule, so switching
a rule off really does drop its hits. `test/bridge_test.dart` exercises the live
Python+Rust path and `test/native_engine_test.dart` the on-device library over
verbatim compiler output; each skips itself when what it needs is absent.
`test/backend_test.dart` pins the dispatch against fake backends and needs no
toolchain at all, and `test/embedded_backend_test.dart` fakes the platform
channel — plus one live test that runs the real `emit-json` output through the
real device engine, which is the embedded path with only Chaquopy standing in
for the transport.

## Screens

- **Rules** — an ordered list of pattern rules, one syntax-highlighted Himark
  source per row. Tap a row to switch it on or off, drag its handle to reorder,
  swipe it left to delete (with undo). The dot at a row's top-right is the
  rule's **colour**, and it is the same colour that rule's hits wear in the Test
  view — so a row is identified by its code and its colour, not by a label.
- **Test** — multiple test strings (chips); the active one as an editor or a
  match-highlighted read view, both under a line-number gutter; a collapsible
  output sheet whose header reports engine status (`Matching…` / count / error)
  and lists each hit with its rule's colour, `[range]` and `Ln n · Col n`.
  The play toggle flips the screen's verb to **run**: the enabled rules, in
  order, run as one script and the read view shows the rewritten document. A
  rule that is a bare query is a one-step statement that writes nothing, so a
  find-only project runs unchanged rather than erroring; a back-referencing
  script is refused by name (resolving it needs the compiler in the engine's
  process, which the Rust engine is not).
- **Settings** — theme (dark/light/system), density, editor font size,
  whitespace glyphs, tab size, restore defaults, reset data.

Plus the shell: the project list (sortable by custom order / name / date, each
project stamped with when it was last edited), per-tab/per-project context menus
(rename / duplicate / delete), a confirm dialog, and undo snackbars.

### Rule colours

`RULE_COLORS` in the brief keys a four-slot palette by rule kind. Rules here
carry no kind, so the palette is cycled by a rule's position in the project.
That position is the one thing the colour must follow, which is why `AppState`
runs only the *enabled* rules through the bridge but maps the bridge's slots
back onto full-list positions before publishing them — otherwise switching one
rule off would recolour every rule under it.

## Structure

```text
lib/
  main.dart               entrypoint
  app.dart                root: theme resolution + HimarkScope
  theme/tokens.dart       Material-3 dark/light token sets + the rule palette
  models/                 project, rules (source highlighter), matcher, bridge
  models/bridge.dart      HejmarkBridge: subprocess bridge to the two engines
  state/                  AppState (ChangeNotifier) + HimarkScope
  screens/                home_scaffold + one file per destination
  widgets/rail.dart       the desktop icon rail
  widgets/rules_panel.dart the rules list, shared by sidebar and screen
  widgets/                top bar, bottom nav, shelf, overlays, shared widgets
```

State is a single `AppState extends ChangeNotifier`, mirroring the brief's
`Component`. The root republishes it through `HimarkScope` on every change.

The shell is **adaptive** (`home_scaffold.dart`). Below 840px logical width it
renders the brief's centred phone frame: a bottom nav across Rules / Test /
Settings, with the project list sliding in over the content. At or above it, a
76px icon rail on the far left opens at most one pinned sidebar — Projects or
Rules — beside a main column that is the editor (or Settings); pressing the open
one closes it and gives the width back to the editor. Rules is therefore a
destination on mobile and a sidebar on desktop, which is why `RulesScreen` is
only a placement around `RulesPanel`.

## Run

```bash
cd gui
flutter pub get
./tool/build_engine.sh      # the on-device engine — build it first
flutter run -d linux        # desktop: the subprocess path runs here
flutter test                # widget flows (fake bridge) + every live path
flutter analyze             # clean
flutter build apk --debug   # an APK with the engine and the compiler inside it
```

`tool/build_engine.sh` needs `cargo`, `cargo-ndk` and the Android NDK, and
cross-compiles `<root>/rust` for `armeabi-v7a`, `arm64-v8a` and `x86_64`
(pass `--host-only` to skip Android and build just the desktop library). Re-run
it after any change to `rust/src/ffi.rs`: the Dart side binds every C symbol up
front, so a stale library fails every call rather than only the new one.

There is no compiler to stage: `android/app/src/main/python/hejmark` symlinks
`<root>/hejmark`. What an APK build does need is the generated ANTLR parser
(`hejmark/adapters/_gen`, gitignored) — `uv run hejmark gen-parser` in the
repository root — and the build fails with that instruction if it is missing.

For the subprocess path, run from inside a checkout so the bridge can find
`.venv` and the Rust `find` binary; build them first with `uv sync` and
`cargo build` (in `<root>/rust`) if needed.

Targets: **Android, iOS, and Linux desktop**. The UI runs on all three, but
matching needs a compiler in reach. **Android has one on the device** — Chaquopy
embeds CPython — and matches the whole language with no toolchain and no
network. Linux gets the same coverage inside a checkout, by subprocess. **iOS
has none**, and since the Rust subset parser was deleted that is now a hole
rather than a degradation: it would need `rust/` built and linked for iOS, and —
because Chaquopy is Android-only — a separate answer for embedding Python
(python-apple-support or equivalent). Neither has been done.

## App identity

The app ships as **Himark Editor**, application ID `dev.himark.editor` (fixed --
F-Droid keys its listing on it), version from `pubspec.yaml`'s `version:` line
(`0.1.0+1` gives versionName `0.1.0`, versionCode `1`).

The launcher icon is generated, not committed art:

```bash
python3 tool/make_icons.py     # stdlib only; no Pillow, no ImageMagick
```

It writes the legacy `mipmap-*/ic_launcher.png` set, the adaptive-icon
foreground `drawable/ic_launcher_foreground.xml` (paired with the background
colour in `values/ic_launcher_background.xml` by `mipmap-anydpi-v26/`), and the
512px listing icon. Edit the geometry in the script and re-run.

**The raster set is not redundant with the adaptive icon**, and dropping it
breaks two things quietly. `mipmap-anydpi-v26/` matches only API 26+, so on the
24--25 devices `minSdk` still admits there is no `mipmap/ic_launcher` at all;
and `fdroidserver` builds a repo's icons by pulling raster entries out of the
APK, so an XML-only icon leaves the F-Droid listing blank. Neither fails the
build. The SVGs under `docs/.notes/icons/` are sketches, not a source of
truth — nothing reads them.

`fastlane/metadata/android/en-US/` is the F-Droid listing (title, descriptions,
changelog, icon) in the layout `fdroidserver` reads. Screenshots go in
`images/phoneScreenshots/`; none are committed yet.

**Not yet ready for F-Droid submission**: the repository has no `LICENSE` file,
and F-Droid only accepts software under a recognised free licence.
