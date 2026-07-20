import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:himark_editor/app.dart';

/// Pins a realistic phone surface so any RenderFlex overflow surfaces as a test
/// failure.
void _usePhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = const Size(1170, 2532); // 390 x 844 logical
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _boot(WidgetTester tester) async {
  _usePhone(tester);
  await tester.pumpWidget(const HimarkApp());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders every tab at phone size without overflow', (
    tester,
  ) async {
    await _boot(tester);
    for (final tab in ['Rules', 'Test', 'Expand', 'Settings']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('toggling a rule updates the active count', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();

    expect(find.text('2 active'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('1 active'), findsOneWidget);
  });

  testWidgets('shelf opens and switches the active project', (tester) async {
    await _boot(tester);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('PROJECTS'), findsOneWidget);

    await tester.tap(find.text('project-a'));
    await tester.pumpAndSettle();
    // Top bar now names project-a; its single rule (ipv4) matches hosts.conf.
    expect(find.text('project-a'), findsWidgets);
    expect(find.text('PROJECTS'), findsNothing); // shelf closed
  });

  testWidgets('expand strip switches the denotation', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Expand'));
    await tester.pumpAndSettle();
    expect(find.text('Final segment — order type ω'), findsOneWidget);

    await tester.tap(find.text('a..z'));
    await tester.pumpAndSettle();
    expect(find.text('Finite range — order type 26'), findsOneWidget);
  });

  testWidgets('theme switch to light rebuilds without error', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Theme'), findsOneWidget);
  });

  testWidgets('test view toggle flips edit/view mode', (tester) async {
    await _boot(tester);
    // Starts in edit mode: the toggle shows the pencil icon.
    expect(find.byIcon(Icons.edit), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    // Now in view mode: the toggle shows the eye icon.
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsing the output sheet keeps the summary', (tester) async {
    await _boot(tester);
    expect(find.text('4 matches'), findsOneWidget);
    await tester.tap(find.text('4 matches'));
    await tester.pumpAndSettle();
    expect(find.text('4 matches'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
