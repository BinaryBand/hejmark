# Himark Editor — Flutter GUI

A Flutter front end for the **Himark Editor** described in
`docs/.notes/Himark Editor.zip` (design brief + screenshots).

The Test tab is wired to the **real hejmark engines** — never to a `RegExp`
approximation. Matching is the actual denotation and the actual matcher, or a
reported error. "Saving…" is still a cosmetic flash and project data lives in
memory for the session.

## Engine bridge

`lib/models/bridge.dart` (`HejmarkBridge`) has two paths to a match. They differ
in how much of the *compiler* is in reach; the matching is the same Rust engine
either way.

```text
on-device   rule.source ──libhejmark.so: parse ▸ denote ▸ match──▶ spans
subprocess  rule.source ──emit-json (python)──▶ floor JSON ──find (rust)──▶ spans
```

**On-device** (`lib/models/native_engine.dart`) is the one that works on a
phone. `<root>/rust` is compiled as a C-ABI shared library (`libhejmark.so`,
`rust/src/ffi.rs`) and linked into the app, so no toolchain is involved. It
parses Himark itself — but only the **floor subset**: the brace syntax that
already is the language's six constructors, plus the `^n` exponent and the
`@hex` splice. Pipelines, back-references, definitions and registers are
reported as `unported` rather than mis-parsed.

**Subprocess** is the repository's portable hand-off, and compiles *all* of
L1.5: each rule's source goes through the Python package (`hejmark emit-json`,
the ANTLR parser + L1.5 expander) into floor-AST JSON, and the Rust `find`
binary denotes that JSON and matches it. Python parses, Rust matches, JSON in
between — see the root `CLAUDE.md`. It needs `<root>/.venv/bin/python` and
`<root>/rust/target/debug/find`, so it is a **desktop-inside-a-checkout**
capability.

The bridge runs the device engine over every rule first, then retries only what
came back `unported` against the subprocess. So a phone matches the common rule
with no toolchain at all, a desktop additionally matches everything else, and
with neither reachable the Test tab reports `engine unavailable`.

- Build the device engine with `./tool/build_engine.sh` before running or
  packaging. The `.so` files it produces are **not committed** — F-Droid builds
  from source and rejects prebuilt binaries — so an APK built without it ships
  no engine.
- Floor JSON is cached per rule source, so a rule is re-parsed only when edited.
- The Rust matcher's maximal-munch does not terminate on an unbounded closure
  (a bare `{X,&X}` Kleene star), so both paths run under a time budget and a
  pattern that blows it shows `pattern too complex`. The device path also runs
  on a background isolate, so a slow rule costs a slow result rather than a
  frozen frame. The seeded rules (IPv4, hex colour, 4-digit number) are all
  bounded spellings the engine settles on quickly.

Widget tests inject a synchronous `Bridge` fake (`test/fake_bridge.dart`) so
flows stay deterministic without any engine — it answers per rule, so switching
a rule off really does drop its hits. `test/bridge_test.dart` exercises the live
Python+Rust path and `test/native_engine_test.dart` the on-device library; each
skips itself when what it needs is absent.

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
flutter run -d linux        # desktop: both engine paths are live here
flutter test                # widget flows (fake bridge) + both live engine paths
flutter analyze             # clean
flutter build apk --debug   # an APK with the engine inside it
```

`tool/build_engine.sh` needs `cargo`, `cargo-ndk` and the Android NDK, and
cross-compiles `<root>/rust` for `armeabi-v7a`, `arm64-v8a` and `x86_64`
(pass `--host-only` to skip Android and build just the desktop library).

For the subprocess path, run from inside a checkout so the bridge can find
`.venv` and the Rust `find` binary; build them first with `uv sync` and
`cargo build` (in `<root>/rust`) if needed.

Targets: **Android, iOS, and Linux desktop**. The UI runs on all three. Android
and Linux also match, through the engine linked into the app; the full L1.5
compiler is a desktop-inside-a-checkout capability on top of that, since it
shells out to the Python and Rust toolchains. iOS would need the library built
and linked for it, which has not been done.

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

`fastlane/metadata/android/en-US/` is the F-Droid listing (title, descriptions,
changelog, icon) in the layout `fdroidserver` reads. Screenshots go in
`images/phoneScreenshots/`; none are committed yet.

**Not yet ready for F-Droid submission**: the repository has no `LICENSE` file,
and F-Droid only accepts software under a recognised free licence.
