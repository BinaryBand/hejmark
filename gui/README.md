# Himark Editor — Flutter GUI

A Flutter front end for the **Himark Editor** described in
`docs/.notes/Himark Editor.zip` (design brief + screenshots).

The Test tab is wired to the **real hejmark engines** by language bridging: each
rule's Himark source is parsed by the Python package (`hejmark emit-json`, the
ANTLR parser + L1.5 expander) into the portable floor-AST JSON, and the Rust
`find` binary denotes that JSON and matches it against the test string. Python
parses, Rust matches, JSON in between — the same hand-off the repository already
defines between the two engines (see the root `CLAUDE.md`). "Saving…" is still a
cosmetic flash and project data lives in memory for the session.

## Engine bridge

`lib/models/bridge.dart` (`HejmarkBridge`) drives both engines as subprocesses:

```text
rule.source ──emit-json (python)──▶ floor JSON ──find (rust)──▶ start⇥end spans
```

- It locates the checkout root (nearest ancestor with `pyproject.toml` + `rust/`)
  and runs `<root>/.venv/bin/python -m hejmark emit-json` and
  `<root>/rust/target/debug/find`. Floor JSON is cached per rule source, so a
  rule is re-parsed only when edited.
- Because both engines are native/interpreted processes, the bridge is a
  **desktop** capability — use `flutter run -d linux` inside a checkout. Off a
  checkout (or on a device without the toolchain) the Test tab reports
  `engine unavailable` rather than matching.
- The Rust matcher's maximal-munch does not terminate on an unbounded closure
  (a bare `{X,&X}` Kleene star), so `find` runs under a time budget; a pattern
  that blows it shows `pattern too complex (engine timed out)`. The seeded rules
  (IPv4, hex colour, 4-digit number) are all bounded spellings the engine
  settles on quickly.

The old Dart `RegExp` approximations are gone; matching is the real engine or a
reported error. Widget tests inject a synchronous `Bridge` fake
(`test/fake_bridge.dart`) so flows stay deterministic without the toolchain, and
`test/bridge_test.dart` exercises the live Python+Rust path.

## Screens

Bottom nav (mobile) / navigation rail (desktop):

- **Rules** — toggle / reorder / add / delete pattern rules, with
  syntax-highlighted Himark source per rule.
- **Test** — multiple test strings (tabs); a code editor with a line-number
  gutter (edit mode) or a match-highlighted read view (view mode); a
  collapsible output sheet whose header reports engine status (`Matching…` /
  count / error) and lists matches with `[range]` and `line:col`.
- **Settings** — theme (dark/light/system), density, editor font size,
  whitespace glyphs, tab size, reset.

Plus the shell: a sliding project shelf, per-tab/per-project context menus
(rename / duplicate / delete), a confirm dialog, and undo snackbars.

## Structure

```text
lib/
  main.dart            entrypoint
  app.dart             root: theme resolution + HimarkScope
  theme/tokens.dart    Material-3 dark/light token sets (from the brief)
  models/              project, rules (source highlighter), matcher, bridge
  models/bridge.dart   HejmarkBridge: subprocess bridge to the Python+Rust engines
  state/               AppState (ChangeNotifier) + HimarkScope inherited widget
  screens/             home_scaffold + one file per tab
  widgets/             top bar, bottom nav, shelf, overlays, shared widgets
```

State is a single `AppState extends ChangeNotifier`, mirroring the brief's
`Component`. The root republishes it through `HimarkScope` on every change.

The shell is **adaptive** (`home_scaffold.dart`): below 840px logical width it
renders the brief's centred phone frame with a bottom nav; at or above it uses a
navigation rail with a multi-pane body (Rules alongside the Test editor).

## Run

```bash
cd gui
flutter pub get
flutter run -d linux        # desktop: the real engine bridge is live here
flutter test                # widget flows (fake bridge) + live-engine bridge test
flutter analyze             # clean
```

Run from inside a checkout so the bridge can find `.venv` and the Rust `find`
binary; build them first with `uv sync` and `cargo build` (in `<root>/rust`) if
needed.

Targets: **Android, iOS, and Linux desktop**. The UI runs on all three, but the
engine bridge is a desktop capability (it shells out to the Python and Rust
toolchains); on a device without them the Test tab reports `engine unavailable`.

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
