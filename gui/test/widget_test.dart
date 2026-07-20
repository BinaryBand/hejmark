import 'package:flutter_test/flutter_test.dart';

import 'package:himark_editor/app.dart';

void main() {
  testWidgets('boots into the demo-set Test screen and finds matches', (
    tester,
  ) async {
    await tester.pumpWidget(const HimarkApp());
    await tester.pumpAndSettle();

    // Top bar shows the seeded project and the bottom nav is present.
    expect(find.text('demo-set'), findsWidgets);
    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Expand'), findsOneWidget);

    // The demo content's email is matched and surfaced in the output sheet.
    expect(find.text('alice.smith@example.com'), findsOneWidget);
    expect(find.text('4 matches'), findsOneWidget);
  });

  testWidgets('navigates to Expand and shows the default denotation', (
    tester,
  ) async {
    await tester.pumpWidget(const HimarkApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Expand'));
    await tester.pumpAndSettle();

    // Default example is the final segment {a..}, order type ω.
    expect(find.text('order type ω'), findsWidgets);
    expect(find.text('Final segment — order type ω'), findsOneWidget);
  });

  testWidgets('opens Settings and lists appearance controls', (tester) async {
    await tester.pumpWidget(const HimarkApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Density'), findsOneWidget);
    expect(find.text('Tab size'), findsOneWidget);
  });
}
