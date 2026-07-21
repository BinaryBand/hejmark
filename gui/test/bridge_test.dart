import 'package:flutter_test/flutter_test.dart';

import 'package:himark_editor/models/bridge.dart';
import 'package:himark_editor/models/project.dart';

// The seeded IPv4 spelling, rebuilt here so the test pins the real hand-off
// rather than importing app state.
const String _octet = r'{{0..9}^3,{0..9}^2,{0..9}}';
const String _ipv4 = '$_octet{\\.}$_octet{\\.}$_octet{\\.}$_octet';

Rule _rule(String source) => Rule(id: 'r', label: 'test', source: source);

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
    final run = await bridge.matchAll(
      <Rule>[_rule(_ipv4)],
      'Server 192.168.1.42 and backup 10.0.0.1 end',
    );
    expect(run.error, isNull);
    expect(
      run.matches.map((m) => m.text),
      containsAll(<String>['192.168.1.42', '10.0.0.1']),
    );
  });

  test('a hex-colour rule using the @hex std splice matches', () async {
    if (skipIfUnavailable()) return;
    final run = await bridge.matchAll(
      <Rule>[_rule(r'{\#}{@hex}^6')],
      'bg #ff8800 and fg #1e90ff done',
    );
    expect(run.error, isNull);
    expect(
      run.matches.map((m) => m.text),
      containsAll(<String>['#ff8800', '#1e90ff']),
    );
  });

  test('multiple rules resolve to sorted, non-overlapping hits', () async {
    if (skipIfUnavailable()) return;
    final run = await bridge.matchAll(
      <Rule>[_rule(_ipv4), _rule(r'{0..9}^4')],
      'host 10.0.0.1 ticket 4821',
    );
    expect(run.error, isNull);
    final starts = run.matches.map((m) => m.start).toList();
    final sorted = <int>[...starts]..sort();
    expect(starts, sorted);
  });

  test('a rule the parser rejects surfaces as an engine error', () async {
    if (skipIfUnavailable()) return;
    final run = await bridge.matchAll(<Rule>[_rule('{a..')], 'abc');
    expect(run.error, isNotNull);
  });

  test('a pipeline rule falls through the device engine to Python', () async {
    if (skipIfUnavailable()) return;
    // `[where ...]` is a value cut, which only the full compiler expands: the
    // device engine reports it `unported` and the bridge retries it here. The
    // hits prove the retry really happened — the cut excludes 25 and 71.
    final run = await bridge.matchAll(<Rule>[
      _rule(r'{0..9}^2[where 30..59]'),
    ], 'ages 25 42 58 71 done');
    expect(run.error, isNull);
    expect(run.matches.map((m) => m.text), <String>['42', '58']);
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
    final bySlot = <int, String>{
      for (final m in run.matches) m.slot: m.text,
    };
    expect(bySlot[0], '#ff8800');
    expect(bySlot[1], '42');
  });
}
