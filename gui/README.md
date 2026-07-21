# Himark Editor — Flutter GUI

A Flutter front end for the **Himark Editor** described in
`docs/.notes/Himark Editor.zip` (design brief + screenshots).

The Test tab is wired to the **real hejmark engines** — never to a `RegExp`
approximation. Matching is the actual denotation and the actual matcher, or a
reported error. "Saving…" is still a cosmetic flash and project data lives in
memory for the session.

## Engine bridge

`lib/models/bridge.dart` (`HejmarkBridge`) has three paths to a match. They
differ in how much of the *compiler* is in reach; the matching is the same Rust
engine every time. `lib/models/backend.dart` is where that shows: a `Compiler`
lowers a rule to a program, an `Engine` runs a program over text, and a
`Backend` is one of each.

```text
on-device   rule.source ──libhejmark.so: parse ▸ denote ▸ match──▶ spans
embedded    rule.source ──emit-json (embedded python)──▶ floor JSON ──┐
subprocess  rule.source ──emit-json (python subprocess)─▶ floor JSON ─┤
                                     libhejmark.so / find (rust) ◀────┘──▶ spans
```

**On-device** (`lib/models/native_backend.dart`) needs nothing at all.
`<root>/rust` is compiled as a C-ABI shared library (`libhejmark.so`,
`rust/src/ffi.rs`) and linked into the app. It parses Himark itself — but only
the **floor subset**: the brace syntax that already is the language's six
constructors, plus the `^n` exponent and the `@hex` splice. Pipelines,
back-references, definitions and registers are reported as `unported` rather
than mis-parsed.

**Embedded** (`lib/models/embedded_backend.dart`, Android) closes that gap on a
phone. Chaquopy embeds CPython in the APK, so the repository's *real* compiler —
ANTLR parser, L1.5 expansion, `emit_json` — runs on the device and emits the
same floor-AST JSON the desktop emits. The program then goes to
`hejmark_find_json` in the library already linked beside it: the compiler moved
onto the device, the engine never left Rust. Dart reaches it over a
MethodChannel (`android/.../MainActivity.kt`), because there is no C ABI to a
Python interpreter.

**Subprocess** is the same hand-off with the compiler in another process:
`<root>/.venv/bin/python -m hejmark emit-json` into `<root>/rust/target/debug/
find`. It compiles all of L1.5 too, and is a **desktop-inside-a-checkout**
capability.

A rule goes to the first backend that will **compile** it, which is what makes
the list a preference order: the floor subset answers the common rule without
waking an interpreter, and whatever it refuses as `unported` falls through. So a
phone now matches *every* rule the language can spell, a desktop does the same
without Chaquopy, and with nothing reachable the Test tab reports `engine
unavailable`.

- Build the device engine with `./tool/build_engine.sh` and stage the compiler
  with `./tool/stage_python.sh` before running or packaging. Neither output is
  committed — F-Droid builds from source and rejects prebuilt binaries — so an
  APK built without them ships no engine and no compiler. The Gradle build fails
  loudly on a missing staged compiler; a missing engine it cannot see.
- Embedding CPython costs about **13.7 MB per ABI** (interpreter, stdlib, and
  the one pure-Python dependency `antlr4-python3-runtime`). The `cli/` layer is
  dropped during staging, which is what keeps `typer` off the device.
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
Python+Rust path and `test/native_engine_test.dart` the on-device library; each
skips itself when what it needs is absent. `test/backend_test.dart` pins the
dispatch against fake backends and needs no toolchain at all, and
`test/embedded_backend_test.dart` fakes the platform channel — plus one live
test that runs the real `emit-json` output through the real device engine, which
is the embedded path with only Chaquopy standing in for the transport.

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
./tool/stage_python.sh      # the on-device compiler — and this second
flutter run -d linux        # desktop: both live engine paths run here
flutter test                # widget flows (fake bridge) + every live path
flutter analyze             # clean
flutter build apk --debug   # an APK with the engine and the compiler inside it
```

`tool/build_engine.sh` needs `cargo`, `cargo-ndk` and the Android NDK, and
cross-compiles `<root>/rust` for `armeabi-v7a`, `arm64-v8a` and `x86_64`
(pass `--host-only` to skip Android and build just the desktop library). Re-run
it after any change to `rust/src/ffi.rs`: the Dart side binds every C symbol up
front, so a stale library fails every call rather than only the new one.

`tool/stage_python.sh` copies `<root>/hejmark` into the app's Chaquopy source
directory, minus `cli/`, generating the ANTLR parser first if it is not there.
The APK build fails if it has not run.

For the subprocess path, run from inside a checkout so the bridge can find
`.venv` and the Rust `find` binary; build them first with `uv sync` and
`cargo build` (in `<root>/rust`) if needed.

Targets: **Android, iOS, and Linux desktop**. The UI runs on all three. Android
and Linux match through the engine linked into the app, and **Android also
compiles the whole language on device**, since Chaquopy embeds CPython there.
Linux gets the same coverage only inside a checkout, by subprocess. iOS has
neither: it would need the library built and linked for it, and — because
Chaquopy is Android-only — a separate answer for embedding Python
(python-apple-support or equivalent). Neither has been done.

## App identity

The app ships as **Himark Editor**, application ID `dev.himark.editor` (fixed --
F-Droid keys its listing on it), version from `pubspec.yaml`'s `version:` line
(`0.1.0+1` gives versionName `0.1.0`, versionCode `1`).

The launcher icon design is defined using vector drawables in XML format for Android. The slate SVG in `docs/.notes/icons/slate.svg` is used as the source of truth for the app's icon design.

- **Android**: The adaptive icon uses an XML vector drawable (`ic_launcher_foreground.xml`) for the foreground and an XML background (`ic_launcher_background.xml`) for the adaptive icon.
- **Adaptive Icon**: The foreground is defined in `drawable/ic_launcher_foreground.xml` and the background in `values/ic_launcher_background.xml`. The adaptive icon is defined in `mipmap-anydpi-v26/ic_launcher.xml`.

The icon design features a modern, clean look based on the slate variant.

To update the icon design:
1. Edit the SVG file in `docs/.notes/icons/slate.svg`.
2. Manually convert the SVG to XML vector drawable paths for `ic_launcher_foreground.xml`.
3. Ensure the `ic_launcher_background.xml` color matches the design.

This approach ensures scalability and consistency across different screen densities.

`fastlane/metadata/android/en-US/` is the F-Droid listing (title, descriptions,
changelog, icon) in the layout `fdroidserver` reads. Screenshots go in
`images/phoneScreenshots/`; none are committed yet.

**Not yet ready for F-Droid submission**: the repository has no `LICENSE` file,
and F-Droid only accepts software under a recognised free licence.
