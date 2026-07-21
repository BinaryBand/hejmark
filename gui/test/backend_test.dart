import 'package:flutter_test/flutter_test.dart';

import 'package:himark_editor/models/backend.dart';
import 'package:himark_editor/models/bridge.dart';
import 'package:himark_editor/models/project.dart';

/// A compiler that answers from a table, so a test can say exactly which rules
/// a backend takes and which it passes on.
class _FakeCompiler implements Compiler {
  _FakeCompiler(this.outcomes);

  /// Source to outcome: a program string, or the refusal to throw.
  final Map<String, Object> outcomes;
  final List<String> asked = <String>[];

  @override
  Future<String> compile(String source) async {
    asked.add(source);
    final outcome = outcomes[source];
    if (outcome is CompileRefusal) throw outcome;
    if (outcome is String) return outcome;
    return source;
  }
}

/// An engine that answers from a table keyed by program.
class _FakeEngine implements Engine {
  _FakeEngine(this.results);

  final Map<String, EngineResult> results;
  final List<List<String>> batches = <List<String>>[];

  @override
  Future<List<EngineResult>> findAll(List<String> programs, String text) async {
    batches.add(programs);
    return <EngineResult>[
      for (final program in programs)
        results[program] ?? const EngineResult(<(int, int)>[]),
    ];
  }
}

Rule _rule(String source, {String label = 'rule'}) =>
    Rule(id: source, label: label, source: source);

void main() {
  test('a retryable refusal falls through to the next backend', () async {
    final first = _FakeCompiler(<String, Object>{
      'pipeline': const CompileRefusal(
        'needs the full compiler',
        retryable: true,
      ),
    });
    final second = _FakeCompiler(<String, Object>{'pipeline': 'compiled'});
    final secondEngine = _FakeEngine(<String, EngineResult>{
      'compiled': const EngineResult(<(int, int)>[(0, 3)]),
    });
    final bridge = HejmarkBridge(
      backends: <Backend>[
        Backend(compiler: first, engine: _FakeEngine(const {})),
        Backend(compiler: second, engine: secondEngine),
      ],
    );

    final run = await bridge.matchAll(<Rule>[_rule('pipeline')], 'abcdef');

    expect(run.error, isNull);
    expect(run.matches.single.text, 'abc');
    expect(second.asked, <String>['pipeline']);
    // The refusing backend must not also be handed the rule to match.
    expect(secondEngine.batches, <List<String>>[
      <String>['compiled'],
    ]);
  });

  test('a final refusal stops rather than trying the next backend', () async {
    final first = _FakeCompiler(<String, Object>{
      'bad': const CompileRefusal('unclosed brace'),
    });
    final second = _FakeCompiler(<String, Object>{'bad': 'compiled'});
    final bridge = HejmarkBridge(
      backends: <Backend>[
        Backend(compiler: first, engine: _FakeEngine(const {})),
        Backend(compiler: second, engine: _FakeEngine(const {})),
      ],
    );

    final run = await bridge.matchAll(<Rule>[
      _rule('bad', label: 'IPv4'),
    ], 'abcdef');

    expect(run.error, 'IPv4: unclosed brace');
    expect(second.asked, isEmpty);
  });

  test('the last refusal is the one reported', () async {
    // The device engine says "needs the full compiler"; the full compiler says
    // what is actually wrong. The second answer is the useful one.
    final bridge = HejmarkBridge(
      backends: <Backend>[
        Backend(
          compiler: _FakeCompiler(<String, Object>{
            'r': const CompileRefusal(
              'needs the full compiler',
              retryable: true,
            ),
          }),
          engine: _FakeEngine(const {}),
        ),
        Backend(
          compiler: _FakeCompiler(<String, Object>{
            'r': const CompileRefusal('unknown name @nope'),
          }),
          engine: _FakeEngine(const {}),
        ),
      ],
    );

    final run = await bridge.matchAll(<Rule>[_rule('r')], 'abcdef');

    expect(run.error, 'rule: unknown name @nope');
  });

  test(
    'a rule refused everywhere reports the reason it was passed on',
    () async {
      // The retry target is absent, so the device engine's own message is all
      // there is — and it is the right thing to show.
      final bridge = HejmarkBridge(
        backends: <Backend>[
          Backend(
            compiler: _FakeCompiler(<String, Object>{
              'r': const CompileRefusal(
                'a pipeline needs the full compiler',
                retryable: true,
              ),
            }),
            engine: _FakeEngine(const {}),
          ),
        ],
      );

      final run = await bridge.matchAll(<Rule>[_rule('r')], 'abcdef');

      expect(run.error, 'rule: a pipeline needs the full compiler');
      expect(run.matches, isEmpty);
    },
  );

  test('both backends contribute to one run, each keeping its slot', () async {
    final bridge = HejmarkBridge(
      backends: <Backend>[
        Backend(
          compiler: _FakeCompiler(<String, Object>{
            'device': 'device',
            'python': const CompileRefusal('needs another compiler', retryable: true),
          }),
          engine: _FakeEngine(<String, EngineResult>{
            'device': const EngineResult(<(int, int)>[(4, 7)]),
          }),
        ),
        Backend(
          compiler: _FakeCompiler(<String, Object>{'python': 'python'}),
          engine: _FakeEngine(<String, EngineResult>{
            'python': const EngineResult(<(int, int)>[(0, 3)]),
          }),
        ),
      ],
    );

    final run = await bridge.matchAll(<Rule>[
      _rule('device'),
      _rule('python'),
    ], 'abc def ghi');

    expect(run.error, isNull);
    // Sorted by position, but each hit still wears the slot of its own rule —
    // which is what colours it downstream.
    expect(run.matches.map((m) => (m.slot, m.text)), <(int, String)>[
      (1, 'abc'),
      (0, 'def'),
    ]);
  });

  test('every rule a backend compiled crosses in one batch', () async {
    final engine = _FakeEngine(const {});
    final bridge = HejmarkBridge(
      backends: <Backend>[
        Backend(compiler: _FakeCompiler(const {}), engine: engine),
      ],
    );

    await bridge.matchAll(<Rule>[_rule('a'), _rule('b'), _rule('c')], 'abcdef');

    expect(engine.batches, <List<String>>[
      <String>['a', 'b', 'c'],
    ]);
  });

  test('an engine failure is reported against its own rule', () async {
    final bridge = HejmarkBridge(
      backends: <Backend>[
        Backend(
          compiler: _FakeCompiler(const {}),
          engine: _FakeEngine(<String, EngineResult>{
            'slow': const EngineResult.failed('pattern too complex'),
          }),
        ),
      ],
    );

    final run = await bridge.matchAll(<Rule>[
      _rule('slow', label: 'Kleene'),
    ], 'abcdef');

    expect(run.error, 'Kleene: pattern too complex');
  });

  test(
    'with no backends at all the run degrades rather than throwing',
    () async {
      final bridge = HejmarkBridge(backends: const <Backend>[]);

      final run = await bridge.matchAll(<Rule>[_rule('r')], 'abcdef');

      expect(run.matches, isEmpty);
      expect(run.error, contains('engine unavailable'));
    },
  );
}
