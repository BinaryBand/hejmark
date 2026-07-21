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
  File? runBin,
}) => Backend(
  compiler: SubprocessCompiler(python: python, root: root),
  engine: BinaryEngine(
    findBin: findBin,
    runBin: runBin,
    root: root,
    timeout: timeout,
  ),
);

/// Compiles by running the checkout's `hejmark` CLI: `emit-json` lowers a rule
/// to the floor AST, `emit-program` lowers a whole script to Program JSON —
/// the same ANTLR parser and L1.5 expander behind both.
class SubprocessCompiler implements Compiler {
  SubprocessCompiler({required this.python, required this.root});

  /// The checkout's interpreter, `.venv/bin/python`.
  final File python;

  /// Run from the repository root, so `-m hejmark` resolves.
  final Directory root;

  /// Outcome by source, one map per program shape: the JSON where it compiled,
  /// the refusal otherwise.
  ///
  /// Both outcomes are cached, for the same reason — the answer cannot change
  /// while the source does not — which spares a broken rule a process spawn
  /// per keystroke as well as sparing a good one a recompile. The maps are
  /// separate because the same text can be both a query and a script, and
  /// `emit-json` and `emit-program` answer differently.
  final Map<String, Object> _queryOutcomes = <String, Object>{};
  final Map<String, Object> _scriptOutcomes = <String, Object>{};

  @override
  Future<String> compile(String source) =>
      _cached(_queryOutcomes, 'emit-json', source);

  @override
  Future<String> compileScript(String source) =>
      _cached(_scriptOutcomes, 'emit-program', source);

  Future<String> _cached(
    Map<String, Object> outcomes,
    String command,
    String source,
  ) async {
    final outcome = outcomes[source] ?? await _emit(command, source);
    outcomes[source] = outcome;
    if (outcome is CompileRefusal) throw outcome;
    return outcome as String;
  }

  Future<Object> _emit(String command, String source) async {
    final temp = Directory.systemTemp.createTempSync('hejmark_compile_');
    try {
      final srcFile = File('${temp.path}/query.hmk')..writeAsStringSync(source);
      final result = await Process.run(python.path, <String>[
        '-m',
        'hejmark',
        command,
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

/// Matches and runs compiled JSON with the Rust binaries, one process per
/// program: `find` prints spans, `run` prints the rewritten document.
class BinaryEngine implements Engine {
  BinaryEngine({
    required this.findBin,
    required this.root,
    required this.timeout,
    this.runBin,
  });

  /// `rust/target/debug/find` — debug, which is what `cargo build` leaves.
  final File findBin;

  /// `rust/target/debug/run`, or null in a checkout built before it existed.
  /// [run] then reports rather than throwing, exactly as a missing engine does.
  final File? runBin;

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

  @override
  Future<RunResult> run(String program, String document) async {
    final bin = runBin;
    if (bin == null) {
      return const RunResult.failed(
        'run binary not built — run `cargo build` in rust/',
      );
    }
    final temp = Directory.systemTemp.createTempSync('hejmark_run_');
    try {
      final programFile = File('${temp.path}/program.json')
        ..writeAsStringSync(program);
      final target = File('${temp.path}/target.txt')
        ..writeAsStringSync(document);
      final (code, out, err) = await _spawn(bin, programFile.path, target.path);
      if (code == _timedOut) {
        return const RunResult.failed('script too complex (engine timed out)');
      }
      if (code != 0) return RunResult.failed(_firstLine(err));
      // Verbatim: the body *is* the document, trailing whitespace included.
      return RunResult(out);
    } finally {
      temp.deleteSync(recursive: true);
    }
  }

  /// Denotes and matches one JSON query, returning `(start, end)` code-point
  /// spans. Killed past [timeout].
  Future<EngineResult> _find(String queryPath, String targetPath) async {
    final (code, out, err) = await _spawn(findBin, queryPath, targetPath);
    if (code == _timedOut) {
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

  static const int _timedOut = -999;

  /// Both binaries share a shape — program path, target path, answer on
  /// stdout, diagnosis on stderr — so one spawn serves either. Killed past
  /// [timeout], reported as [_timedOut].
  Future<(int, String, String)> _spawn(
    File bin,
    String programPath,
    String targetPath,
  ) async {
    final proc = await Process.start(bin.path, <String>[
      programPath,
      targetPath,
    ], workingDirectory: root.path);
    final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
    final stderrFuture = proc.stderr.transform(utf8.decoder).join();
    final code = await proc.exitCode.timeout(
      timeout,
      onTimeout: () {
        proc.kill(ProcessSignal.sigkill);
        return _timedOut;
      },
    );
    return (code, await stdoutFuture, await stderrFuture);
  }
}

String _firstLine(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 'engine error';
  return trimmed.split('\n').first;
}
