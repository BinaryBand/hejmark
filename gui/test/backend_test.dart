import 'package:flutter_test/flutter_test.dart';

import 'package:himark_editor/models/backend.dart';
import 'package:himark_editor/models/bridge.dart';
import 'package:himark_editor/models/project.dart';

/// A compiler that answers from a table, so a test can say exactly which rules
/// a backend takes and which it passes on.
class _FakeCompiler implements Compiler {
  _FakeCompiler(this.outcomes, {this.setRefusal});

  /// Source to outcome: a program string, a [CompileRefusal] against that one
  /// rule, or null for "declares only". Shared by both verbs, since what the
  /// dispatch tests care about is who took the source, not which shape came
  /// back. A source the table does not mention compiles to itself.
  final Map<String, Object?> outcomes;

  /// Thrown instead of answering — the refusal that is about the whole set.
  final CompileRefusal? setRefusal;

  final List<String> asked = <String>[];

  @override
  Future<List<CompiledFragment>> compileAll(List<String> sources) async {
    final refusal = setRefusal;
    if (refusal != null) throw refusal;
    asked.addAll(sources);
    return <CompiledFragment>[
      for (final source in sources)
        switch (outcomes.containsKey(source) ? outcomes[source] : source) {
          final CompileRefusal one => CompiledFragment.refused(one),
          final String program => CompiledFragment.program(program),
          _ => const CompiledFragment.declarations(),
        },
    ];
  }

  @override
  Future<String> compileScript(String source) async {
    asked.add(source);
    final outcome = outcomes[source];
    if (outcome is CompileRefusal) throw outcome;
    if (outcome is String) return outcome;
    return source;
  }
}

/// An engine that answers from a table keyed by program.
class _FakeEngine implements Engine {
  _FakeEngine(this.results, {this.runs = const <String, RunResult>{}});

  final Map<String, EngineResult> results;
  final List<List<String>> batches = <List<String>>[];

  /// Program to run outcome; anything unlisted comes back unchanged.
  final Map<String, RunResult> runs;
  final List<String> ran = <String>[];

  @override
  Future<List<EngineResult>> findAll(List<String> programs, String text) async {
    batches.add(programs);
    return <EngineResult>[
      for (final program in programs)
        results[program] ?? const EngineResult(<(int, int)>[]),
    ];
  }

  @override
  Future<RunResult> run(String program, String document) async {
    ran.add(program);
    return runs[program] ?? RunResult(document);
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

  test('a rule that only declares takes no slot and no blame', () async {
    // `uni d = {0..9}` is a legal rule: it contributes a name to its
    // neighbours and asks nothing, so it reaches no engine and reports no
    // error — the state that has no single-rule spelling at all.
    final engine = _FakeEngine(const {});
    final bridge = HejmarkBridge(
      backends: <Backend>[
        Backend(
          compiler: _FakeCompiler(<String, Object?>{'decl': null}),
          engine: engine,
        ),
      ],
    );

    final run = await bridge.matchAll(<Rule>[
      _rule('decl'),
      _rule('query'),
    ], 'abcdef');

    expect(run.error, isNull);
    expect(engine.batches, <List<String>>[
      <String>['query'],
    ]);
  });

  test('a refusal about the whole set is reported without a rule', () async {
    // Two rules declaring one name is nobody's rule to fix, so the message
    // arrives bare rather than pinned on whichever rule was asked first.
    final bridge = HejmarkBridge(
      backends: <Backend>[
        Backend(
          compiler: _FakeCompiler(
            const <String, Object?>{},
            setRefusal: const CompileRefusal('duplicate name: d'),
          ),
          engine: _FakeEngine(const {}),
        ),
      ],
    );

    final run = await bridge.matchAll(<Rule>[
      _rule('a', label: 'first'),
      _rule('b', label: 'second'),
    ], 'abcdef');

    expect(run.error, 'duplicate name: d');
    expect(run.matches, isEmpty);
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

  // --- the other verb: runScript through the same dispatch -------------------

  test('a script runs on the first backend that compiles it', () async {
    final engine = _FakeEngine(const {}, runs: <String, RunResult>{
      'compiled': const RunResult('rewritten'),
    });
    final bridge = HejmarkBridge(
      backends: <Backend>[
        Backend(
          compiler: _FakeCompiler(<String, Object>{'script': 'compiled'}),
          engine: engine,
        ),
      ],
    );

    final run = await bridge.runScript('script', 'document');

    expect(run.error, isNull);
    expect(run.document, 'rewritten');
    expect(engine.ran, <String>['compiled']);
  });

  test('a retryable script refusal falls through to the next backend',
      () async {
    final second = _FakeEngine(const {}, runs: <String, RunResult>{
      'compiled': const RunResult('rewritten'),
    });
    final bridge = HejmarkBridge(
      backends: <Backend>[
        Backend(
          compiler: _FakeCompiler(<String, Object>{
            'script': const CompileRefusal(
              'needs the full compiler',
              retryable: true,
            ),
          }),
          engine: _FakeEngine(const {}),
        ),
        Backend(
          compiler: _FakeCompiler(<String, Object>{'script': 'compiled'}),
          engine: second,
        ),
      ],
    );

    final run = await bridge.runScript('script', 'document');

    expect(run.error, isNull);
    expect(run.document, 'rewritten');
  });

  test('a final script refusal stops and is the reported message', () async {
    final second = _FakeCompiler(<String, Object>{'bad': 'compiled'});
    final bridge = HejmarkBridge(
      backends: <Backend>[
        Backend(
          compiler: _FakeCompiler(<String, Object>{
            'bad': const CompileRefusal('unclosed brace'),
          }),
          engine: _FakeEngine(const {}),
        ),
        Backend(compiler: second, engine: _FakeEngine(const {})),
      ],
    );

    final run = await bridge.runScript('bad', 'document');

    expect(run.document, isNull);
    expect(run.error, 'unclosed brace');
    expect(second.asked, isEmpty);
  });

  test('an engine that cannot take the script reports rather than throws',
      () async {
    // The Rust engine refusing a back-referencing program at load is the live
    // case: compiled fine, refused by name where it would run.
    final bridge = HejmarkBridge(
      backends: <Backend>[
        Backend(
          compiler: _FakeCompiler(const {}),
          engine: _FakeEngine(const {}, runs: <String, RunResult>{
            'slotted': const RunResult.failed('factor 2 back-references'),
          }),
        ),
      ],
    );

    final run = await bridge.runScript('slotted', 'document');

    expect(run.document, isNull);
    expect(run.error, 'factor 2 back-references');
  });

  test('with no backends a script run degrades rather than throwing',
      () async {
    final bridge = HejmarkBridge(backends: const <Backend>[]);

    final run = await bridge.runScript('script', 'document');

    expect(run.document, isNull);
    expect(run.error, contains('engine unavailable'));
  });
}
