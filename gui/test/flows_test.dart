import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:himark_editor/app.dart';
import 'package:himark_editor/state/scope.dart';
import 'package:himark_editor/theme/schemes.dart';
import 'package:himark_editor/widgets/common.dart';
import 'package:himark_editor/widgets/rail.dart';
import 'package:himark_editor/widgets/rule_code.dart';
import 'package:himark_editor/widgets/top_bar.dart';

import 'fake_bridge.dart';

/// Pins a realistic phone surface so any RenderFlex overflow surfaces as a test
/// failure.
void _usePhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = const Size(1170, 2532); // 390 x 844 logical
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pins a wide desktop surface so the adaptive layout takes the rail path.
void _useDesktop(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1280, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Let every debounced timer land: the 220ms match debounce, the 800ms save
/// flash, and the 4.5s snackbar. Leaving one pending fails the test at teardown.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<void> _boot(WidgetTester tester) async {
  _usePhone(tester);
  await tester.pumpWidget(const HimarkApp(bridge: FakeBridge()));
  await _settle(tester);
}

Future<void> _bootDesktop(WidgetTester tester) async {
  _useDesktop(tester);
  await tester.pumpWidget(const HimarkApp(bridge: FakeBridge()));
  await _settle(tester);
}

void main() {
  testWidgets('renders every tab at phone size without overflow', (
    tester,
  ) async {
    await _boot(tester);
    for (final tab in ['Rules', 'Test', 'Settings']) {
      await tester.tap(find.text(tab));
      await _settle(tester);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Test top bar puts its controls against the right edge', (
    tester,
  ) async {
    await _boot(tester);

    // The collapse-tabs chevron is the last control, so its right edge is the
    // top bar's own right padding and nothing more. This failed while the row
    // held a flex-1 `Flexible` title beside a flex-1 `Spacer`: the two split
    // the free space, and the loose title handed its half back as a gap.
    final last = tester.getRect(
      find
          .descendant(
            of: find.byType(TopBar),
            matching: find.byType(CircleIconButton),
          )
          .last,
    );
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(last.right, closeTo(width - 8, 0.5));
  });

  testWidgets('the Settings foot spreads its title against its button', (
    tester,
  ) async {
    await _bootDesktop(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await _settle(tester);

    // The foot's `Wrap` must span the card's whole inner width — the same
    // inset the dividers wear — so `spaceBetween` has slack to spend and the
    // title ends up opposite its button. Shrink-wrapped (the bug) the card's
    // column centred it instead, insetting title and button by equal slack and
    // reading as a cramped pair adrift in the middle.
    //
    // Widths, not the pair's own gap: the test font makes every glyph a
    // fontSize-wide square, so the run breaks onto a second line here at
    // widths where real text sits on one, and a gap assertion would measure
    // the font rather than the layout.
    final wrap = tester.getRect(find.byType(Wrap).last);
    // Anchored on the row's leading icon, not its text: the cheat-sheet entry
    // carries an icon before the label, so the text is legitimately inset from
    // the card edge while the row itself is not.
    final spec = tester.getRect(find.byIcon(Icons.menu_book_outlined));
    final specEnd = tester.getRect(find.byIcon(Icons.chevron_right));
    expect(wrap.left, closeTo(spec.left, 0.5));
    expect(wrap.right, closeTo(specEnd.right, 0.5));

    // And the title itself sits at that edge rather than inset from it.
    expect(
      tester.getRect(find.text('Reset app data')).left,
      closeTo(wrap.left, 0.5),
    );
  });

  testWidgets('tapping a rule row toggles it and the match count follows', (
    tester,
  ) async {
    await _boot(tester);
    // Seeded: IPv4 and hex-colour on, the 4-digit rule off — 2 hits each.
    expect(find.text('4 matches'), findsOneWidget);

    await tester.tap(find.text('Rules'));
    await _settle(tester);
    await tester.tap(find.byType(RuleCode).first); // the IPv4 rule
    await _settle(tester);

    await tester.tap(find.text('Test'));
    await _settle(tester);
    expect(find.text('2 matches'), findsOneWidget);
  });

  testWidgets('shelf opens and switches the active project', (tester) async {
    await _boot(tester);
    await tester.tap(find.byIcon(Icons.menu));
    await _settle(tester);
    expect(find.text('PROJECTS'), findsOneWidget);

    await tester.tap(find.text('project-a'));
    await _settle(tester);
    // Top bar now names project-a; its single rule (ipv4) hits both hosts.
    expect(find.text('project-a'), findsWidgets);
    expect(find.text('PROJECTS'), findsNothing); // shelf closed
    expect(find.text('2 matches'), findsOneWidget);
  });

  testWidgets('the shelf stamps each project and cycles its sort', (
    tester,
  ) async {
    await _boot(tester);
    await tester.tap(find.byIcon(Icons.menu));
    await _settle(tester);

    // Seeded edit times, one per relative bucket.
    expect(find.text('Edited 2h ago'), findsOneWidget);
    expect(find.text('Edited 1d ago'), findsOneWidget);
    expect(find.text('Edited 9d ago'), findsNothing); // past a week: a date

    // manual → name → date, and the direction toggle flips independently.
    expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget);
    await tester.tap(find.byIcon(Icons.format_list_bulleted));
    await _settle(tester);
    expect(find.byIcon(Icons.sort_by_alpha), findsOneWidget);

    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await _settle(tester);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme switch to light rebuilds without error', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Settings'));
    await _settle(tester);

    await tester.tap(find.text('Light'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Theme'), findsOneWidget);
  });

  testWidgets('restoring defaults asks first, then puts font size back', (
    tester,
  ) async {
    await _boot(tester);
    await tester.tap(find.text('Settings'));
    await _settle(tester);

    // The page is taller than a phone; bring each control up before pressing.
    await tester.ensureVisible(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.add)); // font size up
    await _settle(tester);
    expect(find.text('14px'), findsOneWidget);

    await tester.ensureVisible(find.text('Restore'));
    await tester.tap(find.text('Restore'));
    await _settle(tester);
    expect(find.text('Restore default settings?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await _settle(tester);
    expect(find.text('13px'), findsOneWidget);
  });

  testWidgets('test view toggle flips edit/view mode', (tester) async {
    await _boot(tester);
    // Starts in edit mode: the toggle shows the pencil icon.
    expect(find.byIcon(Icons.edit), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit));
    await _settle(tester);
    // Now in view mode: the toggle shows the eye icon.
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('run mode runs the rules as a script and back again', (
    tester,
  ) async {
    await _boot(tester);
    expect(find.text('4 matches'), findsOneWidget);

    // The play toggle flips the Test screen's verb and leaves edit mode; the
    // seeded rules are bare queries, so the fake — like the real engine —
    // returns the document unchanged.
    await tester.tap(find.byIcon(Icons.play_arrow_outlined));
    await _settle(tester);
    expect(find.text('Ran — document unchanged'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    // Back to find mode: the match count returns.
    await tester.tap(find.byIcon(Icons.play_arrow_outlined));
    await _settle(tester);
    expect(find.text('4 matches'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the output sheet starts collapsed and expands to the hits', (
    tester,
  ) async {
    await _boot(tester);
    expect(find.text('4 matches'), findsOneWidget);
    expect(find.text('192.168.1.42'), findsNothing); // collapsed

    await tester.tap(find.text('4 matches'));
    await _settle(tester);
    expect(find.text('192.168.1.42'), findsOneWidget);
    expect(find.text('Ln 1 · Col 11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'wide layout shows the rail with Projects pinned beside the editor',
    (tester) async {
      await _bootDesktop(tester);

      expect(find.byType(DeskRail), findsOneWidget);
      // Projects is the rail's opening state, so the shelf is a column, not a
      // drawer — and the editor sits beside it with its output sheet.
      expect(find.text('PROJECTS'), findsOneWidget);
      expect(find.text('4 matches'), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsNothing); // the rail owns this job
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wide layout: the rail swaps sidebars and closes the open one', (
    tester,
  ) async {
    await _bootDesktop(tester);

    await tester.tap(find.widgetWithText(InkWell, 'Rules'));
    await _settle(tester);
    expect(find.text('PROJECTS'), findsNothing);
    expect(find.text('RULES'), findsOneWidget);

    // Pressing the open one again gives the width back to the editor.
    await tester.tap(find.widgetWithText(InkWell, 'Rules'));
    await _settle(tester);
    expect(find.text('RULES'), findsNothing);
    expect(find.text('4 matches'), findsOneWidget);
  });

  testWidgets('the app bar book opens the cheat sheet and closes it again', (
    tester,
  ) async {
    await _boot(tester);

    expect(find.text('Himark cheat sheet'), findsNothing);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await _settle(tester);

    expect(find.text('Himark cheat sheet'), findsOneWidget);
    // A section heading and a row spelling, so this pins the content and not
    // just the frame.
    expect(find.text('THE SIX CONSTRUCTORS (L1)'), findsOneWidget);
    expect(find.text('{a,b,c}'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await _settle(tester);
    expect(find.text('Himark cheat sheet'), findsNothing);
  });

  testWidgets('the colour scheme is a settings choice and repaints the app', (
    tester,
  ) async {
    await _boot(tester);
    await tester.tap(find.text('Settings'));
    await _settle(tester);

    expect(find.text('Colour scheme'), findsOneWidget);
    // Airy is the shipped default, so switching lands somewhere else. The row
    // sits below the phone's fold, so it has to be scrolled to first.
    await tester.ensureVisible(find.text('Joplin'));
    await _settle(tester);
    await tester.tap(find.text('Joplin'));
    await _settle(tester);

    final state = HimarkScope.stateOf(tester.element(find.byType(TopBar)));
    expect(state.scheme, AppScheme.joplin);
  });

  testWidgets('wide layout: Settings takes the column and drops the sidebar', (
    tester,
  ) async {
    await _bootDesktop(tester);

    await tester.tap(find.widgetWithText(InkWell, 'Settings'));
    await _settle(tester);

    expect(find.text('PROJECTS'), findsNothing); // sidebar gone
    expect(find.text('Preferences'), findsOneWidget); // app bar title
    expect(find.text('Theme'), findsOneWidget); // Settings pane shown
  });
}
