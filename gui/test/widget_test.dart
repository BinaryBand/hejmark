import 'package:flutter_test/flutter_test.dart';

import 'package:himark_editor/app.dart';

import 'fake_bridge.dart';

void main() {
  testWidgets('boots into the html-escape Test screen and counts its matches', (
    tester,
  ) async {
    await tester.pumpWidget(const HimarkApp(bridge: FakeBridge()));
    await tester.pumpAndSettle();

    // Top bar shows the seeded project and the bottom nav is present.
    expect(find.text('html-escape'), findsWidgets);
    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // The output sheet opens collapsed, so the count is the whole report until
    // the user pulls it up: one hit per character the five rules escape.
    expect(find.text('5 matches'), findsOneWidget);
    expect(find.text('&amp;'), findsNothing);
  });

  testWidgets('opens Settings and lists appearance controls', (tester) async {
    await tester.pumpWidget(const HimarkApp(bridge: FakeBridge()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Density'), findsOneWidget);
    expect(find.text('Tab size'), findsOneWidget);
  });
}
