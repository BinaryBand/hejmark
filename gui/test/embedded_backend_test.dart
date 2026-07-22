import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:himark_editor/models/backend.dart';
import 'package:himark_editor/models/bridge.dart';
import 'package:himark_editor/models/embedded_backend.dart';
import 'package:himark_editor/models/native_engine.dart';
import 'package:himark_editor/models/project.dart';
import 'package:himark_editor/models/subprocess_backend.dart';

/// A pipeline: nothing but the real compiler expands it, which is exactly what
/// this file is checking is on the other end of the channel.
const String _wherePipeline = '{0..9}[where 8..12]';

Rule _rule(String source) => Rule(id: source, label: 'test', source: source);

/// The repository root, when the tests run inside a checkout.
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the compiler half, with the platform faked', () {
    const channel = MethodChannel('test/compiler');
    final calls = <String>[];
    final methods = <String>[];
    late String reply;

    setUp(() {
      calls.clear();
      methods.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            calls.addAll((call.arguments['sources'] as List).cast<String>());
            return reply;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('an ok reply yields one program per rule', () async {
      // Null is the third answer and not a failure: that rule declared names
      // for its neighbours and asked nothing.
      reply = 'ok\n[null, {"universes": []}]';
      final compiler = EmbeddedCompiler(channel);
      final fragments = await compiler.compileAll(<String>['uni d = {a}', '@d']);
      expect(fragments[0].program, isNull);
      expect(fragments[0].refusal, isNull);
      expect(fragments[1].program, '{"universes":[]}');
      expect(calls, <String>['uni d = {a}', '@d']);
      expect(methods, <String>['compileFragments']);
    });

    test('an error entry refuses only its own rule', () async {
      reply = 'ok\n[{"error": "unclosed brace"}, {"universes": []}]';
      final compiler = EmbeddedCompiler(channel);
      final fragments = await compiler.compileAll(<String>['{a', '{b}']);
      expect(fragments[0].refusal?.message, 'unclosed brace');
      expect(fragments[0].refusal?.retryable, isFalse);
      expect(fragments[1].program, isNotNull);
    });

    test('a script crosses as compileProgram, cached apart from the rules',
        () async {
      // The same text is both a query and a one-statement script, and the two
      // lowerings answer differently — so the caches must not collide.
      reply = 'ok\n{"format": "hejmark-program"}';
      final compiler = EmbeddedCompiler(channel);
      expect(
        await compiler.compileScript('{a}'),
        '{"format": "hejmark-program"}',
      );
      expect(await compiler.compileScript('{a}'), isNotEmpty);
      reply = 'ok\n[{"universes": []}]';
      expect(
        (await compiler.compileAll(<String>['{a}'])).single.program,
        '{"universes":[]}',
      );
      expect(methods, <String>['compileProgram', 'compileFragments']);
    });

    test('an err reply is a final refusal, never a retryable one', () async {
      // This *is* the full compiler. Nothing downstream could do better, so a
      // bridge that saw `retryable` here would spawn a pointless second attempt.
      reply = 'err\nduplicate name: d';
      final compiler = EmbeddedCompiler(channel);
      await expectLater(
        compiler.compileAll(<String>['uni d = {a}', 'uni d = {b}']),
        throwsA(
          isA<CompileRefusal>()
              .having((r) => r.message, 'message', 'duplicate name: d')
              .having((r) => r.retryable, 'retryable', isFalse),
        ),
      );
    });

    test('both outcomes are cached, so a keystroke crosses once', () async {
      reply = 'err\nduplicate name: d';
      final compiler = EmbeddedCompiler(channel);
      for (var i = 0; i < 3; i++) {
        await expectLater(
          compiler.compileAll(<String>['{a']),
          throwsA(isA<CompileRefusal>()),
        );
      }
      expect(calls, <String>['{a']);
    });

    test('a reply with no message still says something', () async {
      reply = 'err\n';
      final compiler = EmbeddedCompiler(channel);
      await expectLater(
        compiler.compileAll(<String>['{a']),
        throwsA(
          isA<CompileRefusal>().having(
            (r) => r.message,
            'message',
            'the rule could not be compiled',
          ),
        ),
      );
    });
  });

  test('an unanswered channel refuses rather than throwing', () async {
    // Every non-Android platform, and an Android build whose Python failed to
    // stage: the bridge must degrade to an error line, not an exception.
    final compiler = EmbeddedCompiler(const MethodChannel('test/absent'));
    await expectLater(
      compiler.compileAll(<String>['{a}']),
      throwsA(isA<CompileRefusal>().having((r) => r.retryable, 'retryable', isFalse)),
    );
  });

  test('the real compiler pairs with the device engine', () async {
    // The device pairing, minus Chaquopy: `emit-json` is the same compiler
    // Chaquopy embeds, and `hejmark_find_json` is the same call the phone
    // makes. What this pins is that the two halves agree on the payload — and
    // on a rule that has no other way through, since the engine parses nothing
    // and there is no longer a second front end to fall back to.
    final root = _root();
    final engine = NativeEngine.instance(root: root);
    final python = root == null ? null : File('${root.path}/.venv/bin/python');
    if (root == null || engine == null || !(python?.existsSync() ?? false)) {
      markTestSkipped('needs a checkout with .venv and a built libhejmark');
      return;
    }
    final bridge = HejmarkBridge(
      backends: <Backend>[
        Backend(
          compiler: SubprocessCompiler(python: python!, root: root),
          engine: FfiEngine(engine, timeout: const Duration(seconds: 5)),
        ),
      ],
    );
    final run = await bridge.matchAll(<Rule>[
      _rule(_wherePipeline),
    ], '7 8 9 10 11 12 13');

    expect(run.error, isNull);
    expect(run.matches.map((m) => m.text), <String>[
      '8',
      '9',
      '10',
      '11',
      '12',
    ]);
  });

  test('the real compiler pairs with the device engine for a run', () async {
    // The device run path, minus Chaquopy: `emit-program` is the same compiler
    // Chaquopy embeds, and `hejmark_run_json` is the same call the phone
    // makes. The closest thing to device coverage of the second verb without a
    // device.
    final root = _root();
    final engine = NativeEngine.instance(root: root);
    final python = root == null ? null : File('${root.path}/.venv/bin/python');
    if (root == null || engine == null || !(python?.existsSync() ?? false)) {
      markTestSkipped('needs a checkout with .venv and a built libhejmark');
      return;
    }
    final bridge = HejmarkBridge(
      backends: <Backend>[
        Backend(
          compiler: SubprocessCompiler(python: python!, root: root),
          engine: FfiEngine(engine, timeout: const Duration(seconds: 5)),
        ),
      ],
    );
    final run = await bridge.runScript(r'{a} => "b"', 'banana');

    expect(run.error, isNull);
    expect(run.document, 'bbnbnb');
  });
}
