import 'package:flutter_test/flutter_test.dart';

import 'package:himark_editor/models/bridge.dart';
import 'package:himark_editor/models/project.dart';
import 'package:himark_editor/state/app_state.dart';
import 'package:himark_editor/state/persistence.dart';

import 'fake_bridge.dart';

// An IPv4 spelling: bounded exponents and ranges, enough of the surface to pin
// the real hand-off. Written here rather than taken from the seeds, which are
// whole scripts.
const String _octet = r'{{0..9}^3,{0..9}^2,{0..9}}';
const String _ipv4 = '$_octet{\\.}$_octet{\\.}$_octet{\\.}$_octet';

Rule _rule(String source, {String id = 'r'}) =>
    Rule(id: id, label: 'test', source: source);

void main() {
  final bridge = HejmarkBridge();

  // These exercise the real language bridge: the Python parser lowers each rule
  // to floor JSON (`hejmark emit-json`) and the Rust engine denotes and matches
  // it (`find`). They are skipped where that toolchain is not reachable.
  bool skipIfUnavailable() {
    if (bridge.available) return false;
    markTestSkipped('engine toolchain (.venv + rust/target/debug/find) absent');
    return true;
  }

  test('IPv4 rule matches through the Python parser and Rust engine', () async {
    if (skipIfUnavailable()) return;
    final run = await bridge.matchAll(<Rule>[
      _rule(_ipv4),
    ], 'Server 192.168.1.42 and backup 10.0.0.1 end');
    expect(run.error, isNull);
    expect(
      run.matches.map((m) => m.text),
      containsAll(<String>['192.168.1.42', '10.0.0.1']),
    );
  });

  test('a hex-colour rule using the @hex std splice matches', () async {
    if (skipIfUnavailable()) return;
    final run = await bridge.matchAll(<Rule>[
      _rule(r'{\#}{@hex}^6'),
    ], 'bg #ff8800 and fg #1e90ff done');
    expect(run.error, isNull);
    expect(
      run.matches.map((m) => m.text),
      containsAll(<String>['#ff8800', '#1e90ff']),
    );
  });

  test('multiple rules resolve to sorted, non-overlapping hits', () async {
    if (skipIfUnavailable()) return;
    final run = await bridge.matchAll(<Rule>[
      _rule(_ipv4),
      _rule(r'{0..9}^4'),
    ], 'host 10.0.0.1 ticket 4821');
    expect(run.error, isNull);
    final starts = run.matches.map((m) => m.start).toList();
    final sorted = <int>[...starts]..sort();
    expect(starts, sorted);
  });

  test('one rule declares a name and the next one uses it', () async {
    // The rules of a project are the lines of one script: a rule that only
    // declares is legal, matches nothing, and puts its name in scope for the
    // rules beside it.
    if (skipIfUnavailable()) return;
    final run = await bridge.matchAll(<Rule>[
      _rule('uni dec = {0..9}', id: 'decl'),
      _rule('{@dec}^4', id: 'use'),
    ], 'host 10.0.0.1 ticket 4821');
    expect(run.error, isNull);
    expect(run.matches.map((m) => m.text), <String>['4821']);
    // The declaring rule found nothing, so nothing wears its slot.
    expect(run.matches.map((m) => m.slot), everyElement(1));
  });

  test('a name two rules declare is reported without blaming one', () async {
    if (skipIfUnavailable()) return;
    final run = await bridge.matchAll(<Rule>[
      _rule('uni dec = {0..9}', id: 'first'),
      _rule('uni dec = {a}', id: 'second'),
    ], 'abc 123');
    expect(run.error, contains('duplicate name'));
  });

  test('a rule the parser rejects surfaces as an engine error', () async {
    if (skipIfUnavailable()) return;
    final run = await bridge.matchAll(<Rule>[_rule('{a..')], 'abc');
    expect(run.error, isNotNull);
  });

  test('a pipeline rule compiles and matches end to end', () async {
    if (skipIfUnavailable()) return;
    // `[where ...]` is a value cut, which only expansion computes — so this is
    // the whole compiler running, not a subset of it. The hits prove the cut
    // was really applied: it excludes 25 and 71.
    final run = await bridge.matchAll(<Rule>[
      _rule(r'{0..9}^2[where 30..59]'),
    ], 'ages 25 42 58 71 done');
    expect(run.error, isNull);
    expect(run.matches.map((m) => m.text), <String>['42', '58']);
  });

  test('a script runs end to end and returns the rewritten document', () async {
    if (skipIfUnavailable()) return;
    // The other verb over the same backend: `hejmark emit-program` compiles,
    // the Rust `run` binary executes, and the answer is the document itself.
    final run = await bridge.runScript(r'{a} => "b"', 'banana');
    expect(run.error, isNull);
    expect(run.document, 'bbnbnb');
  });

  test('a contracting script settles and the document comes back', () async {
    if (skipIfUnavailable()) return;
    // normalize-space's two statements: a settlement loop under a measure,
    // which is the construct furthest from a find — nothing about spans
    // survives into this answer.
    final run = await bridge.runScript(
      '{\\t,\\r,\\n} => " "\n{\\ }{\\ } <=>[@spellings] " "',
      'a  \t b',
    );
    expect(run.error, isNull);
    expect(run.document, 'a b');
  });

  test('a back-referencing script is refused by name at load', () async {
    if (skipIfUnavailable()) return;
    // The program compiles — the wire format carries the late slot — and the
    // Rust engine refuses it before spending anything, naming the factor.
    final run = await bridge.runScript(r'{a..z}{$1} => "{{$1}}!"', 'aab');
    expect(run.document, isNull);
    expect(run.error, contains('back-reference'));
  });

  test('the seeded html-escape rules rewrite their seeded test string', () async {
    if (skipIfUnavailable()) return;
    // The seeds are real scripts from `static/examples/`, and this is what pins
    // them to the real engine: the fake bridge answers this exact document
    // verbatim, so a seed edited without re-checking it here fails there.
    final state = AppState(bridge: const FakeBridge(), store: MemoryStore());
    addTearDown(state.dispose);
    final project = state.byId['html-escape']!;
    final sources = <String>[for (final rule in project.rules) rule.source];
    expect(sources, FakeBridge.escapeRules);

    final run = await bridge.runScript(
      sources.join('\n'),
      project.tabs.first.content,
    );
    expect(run.error, isNull);
    expect(run.document, FakeBridge.documentsByScript[sources.join('\n')]);
  });

  test(
    'every seeded project runs on the real engine',
    () async {
      if (skipIfUnavailable()) return;
      // The other half of the seed contract: whatever the app opens on must
      // actually execute. `demos/bubble-sort.hmk` is the reason this test exists —
      // it compiles and is then refused by the engine for its back-reference, so
      // "it is a real example" is not by itself enough to seed something.
      final state = AppState(bridge: const FakeBridge(), store: MemoryStore());
      addTearDown(state.dispose);

      final expected = <String, String>{
        'html-escape': '&amp;',
        'markdown-to-html': '<h1>Himark</h1>',
        'slugify': 'creme-brulee-recipe-12-',
      };
      for (final entry in expected.entries) {
        final project = state.byId[entry.key]!;
        final run = await bridge.runScript(
          <String>[for (final rule in project.rules) rule.source].join('\n'),
          project.tabs.first.content,
        );
        expect(run.error, isNull, reason: '${entry.key} failed to run');
        expect(run.document, contains(entry.value), reason: entry.key);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('a script of bare queries leaves the document unchanged', () async {
    if (skipIfUnavailable()) return;
    // A one-step statement refines and writes nothing, so find-shaped rules
    // run as a no-op rather than an error — which is what makes the Test
    // screen's run mode safe on a find-only project.
    final run = await bridge.runScript(r'{0..9}^4', 'id 2024 here');
    expect(run.error, isNull);
    expect(run.document, 'id 2024 here');
  });

  test('both paths contribute to one run, each keeping its slot', () async {
    if (skipIfUnavailable()) return;
    // Slot 0 is floor-subset (device engine), slot 1 is a pipeline (Python).
    // Colours follow the slot, so the merge must not renumber them.
    final run = await bridge.matchAll(<Rule>[
      _rule(r'{\#}{@hex}^6'),
      _rule(r'{0..9}^2[where 30..59]'),
    ], 'bg #ff8800 age 42 end');
    expect(run.error, isNull);
    final bySlot = <int, String>{for (final m in run.matches) m.slot: m.text};
    expect(bySlot[0], '#ff8800');
    expect(bySlot[1], '42');
  });
}
