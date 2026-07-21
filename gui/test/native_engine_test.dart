import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:himark_editor/models/native_engine.dart';

// The seeded IPv4 spelling, rebuilt here so the test pins the real engine
// rather than importing app state.
const String _octet = r'{{0..9}^3,{0..9}^2,{0..9}}';
const String _ipv4 = '$_octet{\\.}$_octet{\\.}$_octet{\\.}$_octet';

/// The repository root, so a desktop test run finds the library `cargo build`
/// produced. On a device it is resolved from the APK by name and this is null.
Directory? _root() {
  for (var dir = Directory.current; ; dir = dir.parent) {
    if (File('${dir.path}/pyproject.toml').existsSync() &&
        Directory('${dir.path}/rust').existsSync()) {
      return dir;
    }
    if (dir.path == dir.parent.path) return null;
  }
}

void main() {
  final engine = NativeEngine.instance(root: _root());

  // This is the engine the APK ships: no Python, no subprocess, just the Rust
  // library linked into the app. It is skipped where `cargo build` has not run.
  bool skipIfAbsent() {
    if (engine != null) return false;
    markTestSkipped('libhejmark absent — run `cargo build --release` in rust/');
    return true;
  }

  test('the seeded IPv4 rule matches with no toolchain in reach', () async {
    if (skipIfAbsent()) return;
    final replies = await engine!.findAll(<String>[
      _ipv4,
    ], 'Server 192.168.1.42 and backup 10.0.0.1 end');
    expect(replies.single.status, EngineStatus.ok);
    expect(replies.single.spans, <(int, int)>[(7, 19), (31, 39)]);
  });

  test('the @hex splice resolves from the on-device std table', () async {
    if (skipIfAbsent()) return;
    final replies = await engine!.findAll(<String>[
      r'{\#}{@hex}^6',
    ], 'bg #ff8800 and fg #1e90ff done');
    expect(replies.single.status, EngineStatus.ok);
    expect(replies.single.spans.length, 2);
  });

  test('every rule of a run comes back in order', () async {
    if (skipIfAbsent()) return;
    final replies = await engine!.findAll(<String>[
      _ipv4,
      r'{0..9}^4',
      r'{\#}{@hex}^6',
    ], 'host 10.0.0.1 ticket 4821');
    expect(replies.length, 3);
    expect(replies[0].spans.length, 1); // the address
    expect(replies[1].spans.length, 1); // the ticket number
    expect(replies[2].spans, isEmpty); // no colour in the text
  });

  test('spans are code points, so astral text stays aligned', () async {
    if (skipIfAbsent()) return;
    // Four astral characters ahead of the digits: a UTF-16 host would say 8.
    final replies = await engine!.findAll(<String>[r'{0..9}^4'], '𝄞𝄞𝄞𝄞2024');
    expect(replies.single.spans, <(int, int)>[(4, 8)]);
  });

  test('a malformed rule is an error, not a crash', () {
    if (skipIfAbsent()) return;
    final reply = engine!.check('{a..');
    expect(reply.status, EngineStatus.error);
    expect(reply.message, contains('unclosed'));
  });

  test('a rule outside the floor subset is unported, not an error', () {
    if (skipIfAbsent()) return;
    // The status is what the bridge reads to decide whether retrying against
    // the full Python compiler is worthwhile.
    expect(engine!.check('{a}[shorter 2]').status, EngineStatus.unported);
    expect(engine.check(r'{$1}').status, EngineStatus.unported);
    expect(engine.check('{@padfree}').status, EngineStatus.unported);
    expect(engine.check(r'{0..9}^4').status, EngineStatus.ok);
  });
}
