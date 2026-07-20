# Himark Editor — Flutter GUI

A mobile-first Flutter reimplementation of the **Himark Editor** described in
`docs/.notes/Himark Editor.zip` (design brief + screenshots).

It is a **self-contained UI prototype**: it does not call the Python `hejmark`
engine. The Test tab matches with the same regex approximations the design brief
ships, and the Expand tab denotes from a curated example library
(`lib/models/expand_examples.dart`) reproducing the screenshots. "Saving…" is a
cosmetic flash, exactly as in the brief — project data lives in memory for the
session.

## Screens

Four-tab bottom nav:

- **Rules** — toggle / reorder / add / delete pattern rules, with
  syntax-highlighted Himark source per rule.
- **Test** — multiple test strings (tabs); a code editor with a line-number
  gutter (edit mode) or a match-highlighted read view (view mode); a
  collapsible output sheet listing matches with `[range]` and `line:col`.
- **Expand** — denote an expression into its ordered entries; an example strip
  selects from the curated library (final segment ω, finite range, cross-axis
  collision, product, subtraction, …).
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
  models/              project, rules (labels/spans/regex), matcher, expand examples
  state/               AppState (ChangeNotifier) + HimarkScope inherited widget
  screens/             home_scaffold + one file per tab
  widgets/             top bar, bottom nav, shelf, overlays, shared widgets
```

State is a single `AppState extends ChangeNotifier`, mirroring the brief's
`Component`. The root republishes it through `HimarkScope` on every change.

## Run

```bash
cd gui
flutter pub get
flutter run -d linux        # desktop preview (enabled)
flutter run                 # or a connected Android/iOS device / emulator
flutter test                # widget + phone-size flow tests
flutter analyze             # clean
```

Targets: **Android, iOS, and Linux desktop**. To add web or another desktop,
run e.g. `flutter create --platforms=web .` first.
