import 'dart:convert';
import 'dart:io';

import 'backend.dart';

/// The checkout backend: the repository's own portable hand-off, as a pair.
///
/// This one was always two programs with a file between them — Python parses
/// and expands, Rust denotes and matches, floor-AST JSON in the middle — so
/// splitting it is only a matter of naming the halves. It compiles *all* of
/// L1.5, and exists only where both toolchains do: a desktop build inside a
/// checkout.
Backend subprocessBackend({
  required File python,
  required File findBin,
  required Directory root,
  required Duration timeout,
}) => Backend(
  compiler: SubprocessCompiler(python: python, root: root),
  engine: FindBinaryEngine(findBin: findBin, root: root, timeout: timeout),
);

/// Compiles by running `hejmark emit-json`: the ANTLR parser and the L1.5
/// expander, lowering a rule to the floor AST as JSON.
class SubprocessCompiler implements Compiler {
  SubprocessCompiler({required this.python, required this.root});

  /// The checkout's interpreter, `.venv/bin/python`.
  final File python;

  /// Run from the repository root, so `-m hejmark` resolves.
  final Directory root;

  /// Outcome by source: the JSON where it compiled, the refusal otherwise.
  ///
  /// Both are cached, for the same reason — the answer cannot change while the
  /// source does not — which spares a broken rule a process spawn per
  /// keystroke as well as sparing a good one a recompile.
  final Map<String, Object> _outcomes = <String, Object>{};

  @override
  Future<String> compile(String source) async {
    final outcome = _outcomes[source] ?? await _emitJson(source);
    _outcomes[source] = outcome;
    if (outcome is CompileRefusal) throw outcome;
    return outcome as String;
  }

  Future<Object> _emitJson(String source) async {
    final temp = Directory.systemTemp.createTempSync('hejmark_compile_');
    try {
      final srcFile = File('${temp.path}/query.hmk')..writeAsStringSync(source);
      final result = await Process.run(python.path, <String>[
        '-m',
        'hejmark',
        'emit-json',
        srcFile.path,
      ], workingDirectory: root.path);
      // The full compiler is the last resort, so its refusal is final: there
      // is nothing left to retry the rule against.
      if (result.exitCode != 0) {
        return CompileRefusal(_firstLine(result.stderr as String));
      }
      return (result.stdout as String).trim();
    } finally {
      temp.deleteSync(recursive: true);
    }
  }
}

/// Matches compiled JSON with the Rust `find` binary, one process per program.
class FindBinaryEngine implements Engine {
  FindBinaryEngine({
    required this.findBin,
    required this.root,
    required this.timeout,
  });

  /// `rust/target/debug/find` — debug, which is what `cargo build` leaves.
  final File findBin;
  final Directory root;

  /// How long one program may run before the process is killed. Maximal-munch
  /// does not terminate on an unbounded closure, so a user-authored rule can
  /// hang; the budget turns that into a reported error instead of a frozen UI.
  final Duration timeout;

  @override
  Future<List<EngineResult>> findAll(List<String> programs, String text) async {
    if (programs.isEmpty) return const <EngineResult>[];
    final temp = Directory.systemTemp.createTempSync('hejmark_find_');
    try {
      // Written once for the whole batch; only the query changes per program.
      final target = File('${temp.path}/target.txt')..writeAsStringSync(text);
      final results = <EngineResult>[];
      for (var i = 0; i < programs.length; i++) {
        final query = File('${temp.path}/query_$i.json')
          ..writeAsStringSync(programs[i]);
        results.add(await _find(query.path, target.path));
      }
      return results;
    } finally {
      temp.deleteSync(recursive: true);
    }
  }

  /// Denotes and matches one JSON query, returning `(start, end)` code-point
  /// spans. Killed past [timeout].
  Future<EngineResult> _find(String queryPath, String targetPath) async {
    final proc = await Process.start(findBin.path, <String>[
      queryPath,
      targetPath,
    ], workingDirectory: root.path);
    final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
    final stderrFuture = proc.stderr.transform(utf8.decoder).join();
    const timedOut = -999;
    final code = await proc.exitCode.timeout(
      timeout,
      onTimeout: () {
        proc.kill(ProcessSignal.sigkill);
        return timedOut;
      },
    );
    final out = await stdoutFuture;
    final err = await stderrFuture;
    if (code == timedOut) {
      return const EngineResult.failed(
        'pattern too complex (engine timed out)',
      );
    }
    if (code != 0) return EngineResult.failed(_firstLine(err));

    final spans = <(int, int)>[];
    for (final line in const LineSplitter().convert(out)) {
      final parts = line.split('\t');
      if (parts.length != 2) continue;
      final start = int.tryParse(parts[0]);
      final end = int.tryParse(parts[1]);
      if (start != null && end != null) spans.add((start, end));
    }
    return EngineResult(spans);
  }
}

String _firstLine(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 'engine error';
  return trimmed.split('\n').first;
}
