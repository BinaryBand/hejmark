import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:himark_editor/models/native_engine.dart';

/// `{0..9}^4` as `hejmark emit-json` compiles it.
///
/// Every fixture here is verbatim compiler output rather than hand-built JSON.
/// That is the point of the file: the engine is now reachable *only* through a
/// compiled program, so what needs pinning is that it reads what the compiler
/// really writes.
const String _fourDigits =
    '{"universes": [{"members": [{"kind": "product", "factors": [{"kind": '
    '"universe", "universe": {"members": [{"kind": "range", "lo": 48, "hi": '
    '57}]}}, {"kind": "universe", "universe": {"members": [{"kind": "range", '
    '"lo": 48, "hi": 57}]}}, {"kind": "universe", "universe": {"members": '
    '[{"kind": "range", "lo": 48, "hi": 57}]}}, {"kind": "universe", '
    '"universe": {"members": [{"kind": "range", "lo": 48, "hi": 57}]}}]}]}]}';

/// A bare range, `{a..e}`.
const String _letters =
    '{"universes": [{"members": [{"kind": "range", "lo": 97, "hi": 101}]}]}';

/// `{0..9}[where 8..12]` compiled — a value cut, so a pipeline, so a construct
/// no Rust front end this app ever shipped could have read. Compiled, it is
/// just a universe, which is the argument for having deleted that front end.
const String _whereProgram =
    '{"universes": [{"members": [{"kind": "product", "factors": [{"kind": '
    '"universe", "universe": {"members": [{"kind": "face", "text": [48]}, '
    '{"kind": "product", "factors": [{"kind": "universe", "universe": '
    '{"members": [{"kind": "face", "text": [49]}, {"kind": "face", "text": '
    '[50]}, {"kind": "face", "text": [51]}, {"kind": "face", "text": [52]}, '
    '{"kind": "face", "text": [53]}, {"kind": "face", "text": [54]}, {"kind": '
    '"face", "text": [55]}, {"kind": "face", "text": [56]}, {"kind": "face", '
    '"text": [57]}]}}]}, {"kind": "product", "factors": [{"kind": "universe", '
    '"universe": {"members": [{"kind": "face", "text": [49]}]}}, {"kind": '
    '"universe", "universe": {"members": [{"kind": "face", "text": [48]}, '
    '{"kind": "face", "text": [49]}, {"kind": "face", "text": [50]}]}}]}, '
    '{"kind": "subtract", "universe": {"members": [{"kind": "face", "text": '
    '[48]}, {"kind": "product", "factors": [{"kind": "universe", "universe": '
    '{"members": [{"kind": "face", "text": [49]}, {"kind": "face", "text": '
    '[50]}, {"kind": "face", "text": [51]}, {"kind": "face", "text": [52]}, '
    '{"kind": "face", "text": [53]}, {"kind": "face", "text": [54]}, {"kind": '
    '"face", "text": [55]}]}}]}]}}]}}]}]}]}';

/// `{a} => "b"` as `hejmark emit-program` compiles it: a whole (one-statement)
/// script in the Program wire shape, which is `hejmark_run_json`'s input.
const String _swapProgram =
    '{"format": "hejmark-program", "version": 1, "sentinels": [], '
    '"statements": [{"kind": "statement", "steps": [{"kind": "query", '
    '"source": "", "factors": [{"kind": "universe", "universe": {"members": '
    '[{"kind": "face", "text": [97]}]}}]}, {"kind": "template", "parts": '
    '[{"kind": "text", "text": [98]}]}]}]}';

/// `{a..z}{\$1} => "{{\$1}}!"` compiled — a late slot rides the wire, and it is
/// the *engine* that refuses it, by name, at load.
const String _slottedProgram =
    '{"format": "hejmark-program", "version": 1, "sentinels": [], '
    '"statements": [{"kind": "statement", "steps": [{"kind": "query", '
    '"source": "", "factors": [{"kind": "universe", "universe": {"members": '
    '[{"kind": "range", "lo": 97, "hi": 122}]}}, {"kind": "slot", "slot": 0, '
    '"needs": [1], "reach": 1}]}, {"kind": "template", "parts": [{"kind": '
    '"capture", "capture": "\$1"}, {"kind": "text", "text": [33]}]}]}]}';

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

  // This is the engine the APK ships: the Rust library linked into the app,
  // matching programs a compiler elsewhere produced. Skipped where `cargo
  // build` has not run.
  bool skipIfAbsent() {
    if (engine != null) return false;
    markTestSkipped('libhejmark absent — run `cargo build --release` in rust/');
    return true;
  }

  test('a compiled rule matches with no compiler in reach', () async {
    if (skipIfAbsent()) return;
    final replies = await engine!.findAll(<String>[
      _fourDigits,
    ], 'id 2024 and ticket 1999 here');
    expect(replies.single.status, EngineStatus.ok);
    expect(replies.single.spans, <(int, int)>[(3, 7), (19, 23)]);
  });

  test('every program of a run comes back in order', () async {
    if (skipIfAbsent()) return;
    final replies = await engine!.findAll(<String>[
      _fourDigits,
      _letters,
      _whereProgram,
    ], '#4821 only');
    expect(replies.length, 3);
    expect(replies[0].spans, <(int, int)>[(1, 5)]); // the four-digit number
    expect(replies[1].spans, isEmpty); // no a–e anywhere in it
    expect(replies[2].spans, <(int, int)>[(2, 3)]); // the 8, in 8..12
  });

  test('spans are code points, so astral text stays aligned', () async {
    if (skipIfAbsent()) return;
    // Four astral characters ahead of the digits: a UTF-16 host would say 8.
    final replies = await engine!.findAll(<String>[_fourDigits], '𝄞𝄞𝄞𝄞2024');
    expect(replies.single.spans, <(int, int)>[(4, 8)]);
  });

  test('a compiled pipeline matches, needing no front end here', () async {
    if (skipIfAbsent()) return;
    // The whole of what running the real compiler buys, exercised without an
    // Android device in reach: `where` is a pipeline, and the engine that
    // matches it never learned what a pipeline is.
    final replies = await engine!.findAll(<String>[
      _whereProgram,
    ], '7 8 9 10 11 12 13');
    expect(replies.single.status, EngineStatus.ok);
    expect(replies.single.spans, <(int, int)>[
      (2, 3),
      (4, 5),
      (6, 8),
      (9, 11),
      (12, 14),
    ]);
  });

  test('a whole script runs and the reply body is the document', () async {
    if (skipIfAbsent()) return;
    // The other entry point, `hejmark_run_json`: a compiled script in, the
    // rewritten document out, raw — parsing is the caller's job because the
    // body is text, not spans.
    final reply = await engine!.run(_swapProgram, 'banana');
    expect(reply, 'ok\nbbnbnb');
  });

  test('a slotted program is refused by name at load', () async {
    if (skipIfAbsent()) return;
    // The wire format carries a late slot fine; resolving one needs the
    // compiler that emitted it, which this library is not — so the refusal
    // lands before the document is touched, and says which factor.
    final reply = await engine!.run(_slottedProgram, 'aab');
    expect(reply, startsWith('err\n'));
    expect(reply, contains('back-reference'));
  });

  test('a query program is not a script, and run says so', () async {
    if (skipIfAbsent()) return;
    final reply = await engine!.run(_fourDigits, 'id 2024');
    expect(reply, startsWith('err\ninvalid program JSON'));
  });

  test('a malformed program is an error rather than a crash', () async {
    if (skipIfAbsent()) return;
    final replies = await engine!.findAll(<String>[
      '{"universes": 3}',
    ], 'text');
    expect(replies.single.status, EngineStatus.error);
    expect(replies.single.message, contains('invalid query JSON'));
  });

  test('unexpanded source is not a program, and is refused as one', () async {
    if (skipIfAbsent()) return;
    // A host that skipped the compiler gets an error, not a match. There is no
    // status between the two any more: this library is the end of the line.
    final replies = await engine!.findAll(<String>[r'{0..9}^4'], 'id 2024');
    expect(replies.single.status, EngineStatus.error);
    expect(replies.single.message, contains('invalid query JSON'));
  });
}
