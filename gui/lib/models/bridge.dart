import 'dart:convert';
import 'dart:io';

import 'matcher.dart';
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

/// Bridges the Flutter GUI to hejmark's real engines by subprocess.
///
/// The repository already defines a portable hand-off: `hejmark emit-json`
/// runs the ANTLR parser and the L1.5 expander to lower a query to the floor
/// AST as JSON, and the Rust `find` binary denotes that JSON and matches it
/// against a target, printing one `start<TAB>end` line (code-point offsets) per
/// non-overlapping hit. This class wires the Test screen onto exactly that
/// hand-off: Python parses, Rust matches, JSON in between.
///
/// It only works where both toolchains are reachable — i.e. the `flutter run
/// -d linux` desktop build inside a checkout — which is why every entry point
/// degrades to a descriptive [MatchRun.error] rather than throwing when the
/// engine is absent.
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

  /// Whether both engines are reachable from here.
  bool get available => _python != null && _findBin != null;

  @override
  Future<MatchRun> matchAll(List<Rule> rules, String content) async {
    final python = _python;
    final findBin = _findBin;
    if (python == null || findBin == null) {
      return const MatchRun(
        <MatchRange>[],
        error:
            'engine unavailable — run the desktop build inside a hejmark '
            'checkout (needs .venv and rust/target/debug/find)',
      );
    }
    if (rules.isEmpty || content.isEmpty) return const MatchRun(<MatchRange>[]);

    final temp = Directory.systemTemp.createTempSync('hejmark_gui_');
    try {
      final target = File('${temp.path}/target.txt')..writeAsStringSync(content);
      final cpSpans = <_Span>[];
      String? error;
      for (var slot = 0; slot < rules.length; slot++) {
        final rule = rules[slot];
        try {
          final jsonPath = await _emitJson(python, rule.source, temp);
          final hits = await _find(findBin, jsonPath, target.path);
          for (final (start, end) in hits) {
            cpSpans.add(_Span(start, end, slot));
          }
        } on _BridgeError catch (e) {
          error ??= '${rule.label}: ${e.message}';
        }
      }
      final ranges = _resolve(content, cpSpans);
      return MatchRun(ranges, error: error);
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
