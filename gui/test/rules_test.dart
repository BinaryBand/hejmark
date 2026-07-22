import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:himark_editor/app.dart';
import 'package:himark_editor/models/project.dart';
import 'package:himark_editor/state/app_state.dart';
import 'package:himark_editor/state/persistence.dart';
import 'package:himark_editor/state/scope.dart';
import 'package:himark_editor/theme/tokens.dart';
import 'package:himark_editor/widgets/rule_code.dart';
import 'package:himark_editor/widgets/rules_panel.dart';

import 'fake_bridge.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Opens the app on the mobile Rules destination.
Future<void> _bootToRules(WidgetTester tester) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = const Size(1170, 2532);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const HimarkApp(bridge: FakeBridge()));
  await _settle(tester);
  await tester.tap(find.text('Rules'));
  await _settle(tester);
}

void main() {
  testWidgets('swiping a rule away deletes it, and Undo puts it back', (
    tester,
  ) async {
    await _bootToRules(tester);
    expect(find.byType(RuleCode), findsNWidgets(3));

    await tester.drag(find.byType(RuleCode).first, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.byType(RuleCode), findsNWidgets(2));
    expect(find.text('Rule removed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(find.byType(RuleCode), findsNWidgets(3));
  });

  testWidgets('adding a rule appends one row, open in its editor', (
    tester,
  ) async {
    await _bootToRules(tester);
    await tester.tap(find.byIcon(Icons.add));
    await _settle(tester);

    // Four rules, but the new one wears the field rather than the highlighted
    // block — a rule you cannot read yet is one you meant to write.
    expect(find.byType(RuleField), findsOneWidget);
    expect(find.byType(RuleCode), findsNWidgets(3));

    await tester.tap(find.byIcon(Icons.check));
    await _settle(tester);
    expect(find.byType(RuleField), findsNothing);
    expect(find.byType(RuleCode), findsNWidgets(4));
  });

  testWidgets('the pencil opens a rule and typing rewrites its source', (
    tester,
  ) async {
    await _bootToRules(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await _settle(tester);
    expect(find.byType(RuleField), findsOneWidget);

    await tester.enterText(find.byType(TextField), r'{a..z}^3');
    await _settle(tester);

    final state = HimarkScope.stateOf(tester.element(find.byType(RulesPanel)));
    expect(state.cur!.rules.first.source, r'{a..z}^3');

    // Tapping an open row must not toggle the rule out from under the cursor.
    expect(state.cur!.enabled['r1'], isTrue);
  });

  test(
    'a hit keeps its rule position when an earlier rule is switched off',
    () async {
      final state = AppState(bridge: const FakeBridge());
      addTearDown(state.dispose);
      await Future<void>.delayed(Duration.zero); // let the eager first run land

      // Seeded order is IPv4 (slot 0), hex colour (slot 1), 4-digit (slot 2, off).
      expect(state.matches.map((m) => m.slot).toSet(), <int>{0, 1});

      // Switching the first rule off must not slide the hex rule into slot 0 —
      // its hits would silently change colour.
      state.toggleRule('r1');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(state.matches, isNotEmpty);
      expect(state.matches.map((m) => m.slot).toSet(), <int>{1});
    },
  );

  test('run mode executes the enabled rules as one script', () async {
    final state = AppState(bridge: const FakeBridge());
    addTearDown(state.dispose);
    await Future<void>.delayed(Duration.zero); // let the eager first run land

    // One rewriting rule; the fake maps its script verbatim.
    final c = state.cur!;
    c.rules.clear();
    c.enabled.clear();
    c.rules.add(Rule(id: 'rs', label: 'swap', source: '{a} => "b"'));
    c.enabled['rs'] = true;

    state.toggleRunMode();
    expect(state.editMode, isFalse); // running is for seeing the document
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(state.runDocument, 'rewritten');
    expect(state.matchSummary, startsWith('Ran — document rewritten'));
  });

  test(
    'a session is written to the store and read back by the next one',
    () async {
      final store = MemoryStore();
      final first = AppState(bridge: const FakeBridge(), store: store);
      await Future<void>.delayed(Duration.zero);

      first.setRuleSource('r1', r'{x}^2');
      first.toggleRule('r3');
      first.setFontSize(17);
      first.setTheme(ThemeChoice.light);
      await Future<void>.delayed(const Duration(milliseconds: 900)); // debounce
      first.dispose();
      expect(store.data, isNotNull);

      final second = AppState(bridge: const FakeBridge(), store: store);
      addTearDown(second.dispose);
      // The seed is what is on screen until the read lands, so wait for it.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(second.cur!.rules.first.source, r'{x}^2');
      expect(second.cur!.enabled['r3'], isTrue);
      expect(second.editorFontSize, 17);
      expect(second.theme, ThemeChoice.light);
      // Ids keep going up across the restart, so a new rule cannot collide with
      // a restored one.
      expect(second.cur!.rules.map((r) => r.id), isNot(contains('r-1')));
    },
  );

  test('an unreadable store leaves the demo seed standing', () async {
    final state = AppState(
      bridge: const FakeBridge(),
      store: MemoryStore('not json at all'),
    );
    addTearDown(state.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(state.cur!.name, 'demo-set');
    expect(state.cur!.rules.length, 3);
  });

  test('the palette cycles rather than running off its end', () {
    expect(darkTokens.ruleColorAt(0), same(darkTokens.ruleColors[0]));
    expect(darkTokens.ruleColorAt(4), same(darkTokens.ruleColors[0]));
    expect(lightTokens.ruleColorAt(5), same(lightTokens.ruleColors[1]));
  });
}
