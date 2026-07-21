import 'dart:convert';
import 'dart:io';

import 'matcher.dart';
import 'native_engine.dart';
import 'project.dart';

/// The result of one match run: the spans found, plus an [error] string when
/// the engine could not be reached, a rule failed to parse, or a pattern ran
/// past the matcher's time budget.
class MatchRun {
  const MatchRun(this.matches, {this.error});
  final List<MatchRange> matches;
  final String? error;
}

/// Runs the project's rules over a test string and returns the spans they hit.
///
/// This is the seam the Test screen talks to. The real implementation
/// ([HejmarkBridge]) drives the actual Python parser and Rust engine as
/// subprocesses; tests inject a synchronous fake so widget flows stay
/// deterministic without the toolchain.
abstract interface class Bridge {
  Future<MatchRun> matchAll(List<Rule> rules, String content);
}

/// Bridges the Flutter GUI to hejmark's real engines.
///
/// There are two paths to a match, and the difference between them is how much
/// of the *compiler* is reachable — never how the matching is done, which is
/// the same Rust engine either way.
///
/// **On-device** ([NativeEngine]): `rust/` is linked into the app as a shared
/// library and called over its C ABI. It compiles the floor subset of Himark
/// itself, so it needs no toolchain and is the only path that exists on a
/// phone. A rule it cannot compile comes back [EngineStatus.unported].
///
/// **By subprocess**: the repository's portable hand-off — `hejmark emit-json`
/// runs the ANTLR parser and the L1.5 expander to lower a query to the floor
/// AST as JSON, and the Rust `find` binary denotes that JSON and matches it,
/// printing one `start<TAB>end` line (code-point offsets) per non-overlapping
/// hit. This compiles *all* of L1.5 but needs both toolchains, so it exists
/// only in a `flutter run -d linux` desktop build inside a checkout.
///
/// So the device engine runs first and the subprocess picks up what it hands
/// back as `unported` — the fast, always-present path answers the common rule,
/// and the full compiler answers the rest wherever it happens to be installed.
/// With neither reachable every entry point degrades to a descriptive
/// [MatchRun.error] rather than throwing.
class HejmarkBridge implements Bridge {
  HejmarkBridge();

  /// How long the Rust matcher may run on one rule before it is killed. The
  /// port's maximal-munch does not terminate on an unbounded closure (e.g. a
  /// bare `{X,&X}` Kleene star), so a user-authored pattern can hang; the
  /// budget turns that into a reported error instead of a frozen UI.
  static const Duration _findBudget = Duration(seconds: 5);

  Directory? _rootCache;
  bool _rootResolved = false;

  /// Floor JSON keyed by rule source, so a rule is re-parsed only when edited.
  final Map<String, String> _jsonBySource = <String, String>{};

  /// The repository root: the nearest ancestor holding both `pyproject.toml`
  /// and a `rust/` tree. Null when the app runs outside a checkout.
  Directory? get _root {
    if (_rootResolved) return _rootCache;
    _rootResolved = true;
    for (var dir = Directory.current; ; dir = dir.parent) {
      final marker = File('${dir.path}/pyproject.toml');
      final rust = Directory('${dir.path}/rust');
      if (marker.existsSync() && rust.existsSync()) {
        _rootCache = dir;
        break;
      }
      if (dir.path == dir.parent.path) break; // reached the filesystem root
    }
    return _rootCache;
  }

  File? get _python {
    final root = _root;
    if (root == null) return null;
    final venv = File('${root.path}/.venv/bin/python');
    return venv.existsSync() ? venv : null;
  }

  File? get _findBin {
    final root = _root;
    if (root == null) return null;
    final bin = File('${root.path}/rust/target/debug/find');
    return bin.existsSync() ? bin : null;
  }

  /// The engine compiled into the app, where one loaded.
  NativeEngine? get _native => NativeEngine.instance(root: _root);

  /// Whether the full L1.5 compiler is reachable — i.e. a rule the device
  /// engine refuses as `unported` has somewhere to be retried.
  bool get _hasCompiler => _python != null && _findBin != null;

  /// Whether any engine can answer at all.
  bool get available => _native != null || _hasCompiler;

  @override
  Future<MatchRun> matchAll(List<Rule> rules, String content) async {
    if (rules.isEmpty || content.isEmpty) return const MatchRun(<MatchRange>[]);
    final native = _native;
    if (native == null && !_hasCompiler) {
      return const MatchRun(
        <MatchRange>[],
        error:
            'engine unavailable — no libhejmark to load, and no hejmark '
            'checkout to fall back on (needs .venv and rust/target/debug/find)',
      );
    }

    // One crossing for the whole run: the device engine takes every rule at
    // once, on one background isolate.
    final replies = native == null
        ? null
        : await native.findAll(
            rules.map((r) => r.source).toList(),
            content,
            timeout: _findBudget,
          );

    final cpSpans = <_Span>[];
    String? error;
    // Slots the device engine could not compile, each carrying the reason it
    // gave — which is the message to show if there is no compiler to retry on.
    final retry = <int, String>{};
    for (var slot = 0; slot < rules.length; slot++) {
      final reply = replies?[slot];
      if (reply == null) {
        retry[slot] = 'engine unavailable';
        continue;
      }
      switch (reply.status) {
        case EngineStatus.unported:
          retry[slot] = reply.message;
        case EngineStatus.error:
          error ??= '${rules[slot].label}: ${reply.message}';
        case EngineStatus.ok:
          for (final (start, end) in reply.spans) {
            cpSpans.add(_Span(start, end, slot));
          }
      }
    }

    if (retry.isNotEmpty) {
      final fallback = await _matchBySubprocess(retry, rules, content);
      cpSpans.addAll(fallback.spans);
      error ??= fallback.error;
    }
    return MatchRun(_resolve(content, cpSpans), error: error);
  }

  /// Runs the given slots through the full compiler, or explains why it cannot.
  ///
  /// [slots] maps each slot to the device engine's reason for passing it on, so
  /// that reason can be reported verbatim when there is no compiler to retry on
  /// — "a pipeline needs the full compiler" is the useful message there, and it
  /// has already been paid for.
  Future<({List<_Span> spans, String? error})> _matchBySubprocess(
    Map<int, String> slots,
    List<Rule> rules,
    String content,
  ) async {
    final python = _python;
    final findBin = _findBin;
    if (python == null || findBin == null) {
      final slot = slots.keys.first;
      return (spans: <_Span>[], error: '${rules[slot].label}: ${slots[slot]}');
    }

    final temp = Directory.systemTemp.createTempSync('hejmark_gui_');
    try {
      final target = File('${temp.path}/target.txt')..writeAsStringSync(content);
      final spans = <_Span>[];
      String? error;
      for (final slot in slots.keys) {
        final rule = rules[slot];
        try {
          final jsonPath = await _emitJson(python, rule.source, temp);
          final hits = await _find(findBin, jsonPath, target.path);
          for (final (start, end) in hits) {
            spans.add(_Span(start, end, slot));
          }
        } on _BridgeError catch (e) {
          error ??= '${rule.label}: ${e.message}';
        }
      }
      return (spans: spans, error: error);
    } finally {
      temp.deleteSync(recursive: true);
    }
  }

  /// Lower a rule's Himark source to floor JSON via the Python parser, caching
  /// by source so an unchanged rule is parsed once per session.
  Future<String> _emitJson(File python, String source, Directory temp) async {
    final cached = _jsonBySource[source];
    if (cached != null) return _writeJson(cached, source, temp);

    final srcFile = File('${temp.path}/query.hmk')..writeAsStringSync(source);
    final result = await Process.run(
      python.path,
      <String>['-m', 'hejmark', 'emit-json', srcFile.path],
      workingDirectory: _root!.path,
    );
    if (result.exitCode != 0) {
      throw _BridgeError(_firstLine(result.stderr as String));
    }
    final json = (result.stdout as String).trim();
    _jsonBySource[source] = json;
    return _writeJson(json, source, temp);
  }

  String _writeJson(String json, String source, Directory temp) {
    final path = '${temp.path}/query_${source.hashCode}.json';
    File(path).writeAsStringSync(json);
    return path;
  }

  /// Denote and match one JSON query against the target with the Rust binary,
  /// returning `(start, end)` code-point spans. Killed past [_findBudget].
  Future<List<(int, int)>> _find(
    File findBin,
    String jsonPath,
    String targetPath,
  ) async {
    final proc = await Process.start(
      findBin.path,
      <String>[jsonPath, targetPath],
      workingDirectory: _root!.path,
    );
    final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
    final stderrFuture = proc.stderr.transform(utf8.decoder).join();
    const timedOut = -999;
    final code = await proc.exitCode.timeout(
      _findBudget,
      onTimeout: () {
        proc.kill(ProcessSignal.sigkill);
        return timedOut;
      },
    );
    final out = await stdoutFuture;
    final err = await stderrFuture;
    if (code == timedOut) {
      throw const _BridgeError('pattern too complex (engine timed out)');
    }
    if (code != 0) throw _BridgeError(_firstLine(err));

    final spans = <(int, int)>[];
    for (final line in const LineSplitter().convert(out)) {
      final parts = line.split('\t');
      if (parts.length != 2) continue;
      final start = int.tryParse(parts[0]);
      final end = int.tryParse(parts[1]);
      if (start != null && end != null) spans.add((start, end));
    }
    return spans;
  }

  /// Turn code-point spans into UTF-16 [MatchRange]s over [content], sorted by
  /// start and with overlaps dropped first-wins — the same resolution the old
  /// regex matcher applied, now over the real engine's hits. Each survivor keeps
  /// the slot of the rule that found it, which is what colours it downstream.
  List<MatchRange> _resolve(String content, List<_Span> cpSpans) {
    final runes = content.runes.toList();
    // Prefix sum mapping a code-point index to its UTF-16 offset.
    final utf16 = List<int>.filled(runes.length + 1, 0);
    for (var i = 0; i < runes.length; i++) {
      utf16[i + 1] = utf16[i] + (runes[i] > 0xFFFF ? 2 : 1);
    }

    final ranges = <MatchRange>[];
    for (final span in cpSpans) {
      final cs = span.start.clamp(0, runes.length);
      final ce = span.end.clamp(0, runes.length);
      if (ce <= cs) continue;
      final a = utf16[cs];
      final b = utf16[ce];
      ranges.add(MatchRange(a, b, content.substring(a, b), slot: span.slot));
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));

    final merged = <MatchRange>[];
    var lastEnd = -1;
    for (final r in ranges) {
      if (r.start >= lastEnd) {
        merged.add(r);
        lastEnd = r.end;
      }
    }
    return merged;
  }
}

String _firstLine(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 'engine error';
  return trimmed.split('\n').first;
}

/// One engine hit before resolution: a code-point span plus the slot of the rule
/// that produced it.
class _Span {
  const _Span(this.start, this.end, this.slot);
  final int start;
  final int end;
  final int slot;
}

/// Internal signal that one rule failed; carried to [MatchRun.error].
class _BridgeError implements Exception {
  const _BridgeError(this.message);
  final String message;
}
