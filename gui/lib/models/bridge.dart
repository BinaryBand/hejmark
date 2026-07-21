import 'dart:io';

import 'backend.dart';
import 'embedded_backend.dart';
import 'matcher.dart';
import 'native_engine.dart';
import 'project.dart';
import 'subprocess_backend.dart';

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
/// Everything below this class is a [Backend] — a [Compiler] that lowers a rule
/// to a program and an [Engine] that runs the program over text. This class
/// owns only what is genuinely about *the run*: which backends exist here,
/// which one takes each rule, and how code-point spans become UTF-16
/// highlights. It contains no compiling and no matching of its own.
///
/// Two backends exist, and they differ only in **where the compiler runs**.
/// Both compile all of L1.5 — the same `hejmark emit-json`, the same floor-AST
/// JSON out — and the matching is the same Rust engine either way:
///
/// **Embedded** (`embedded_backend.dart`, Android): CPython embedded in the app
/// compiles, and the Rust library linked beside it matches. This is the whole
/// language on a phone with no toolchain and no network.
///
/// **By subprocess** (`subprocess_backend.dart`): `hejmark emit-json` in the
/// checkout's `.venv` compiles, and the Rust `find` binary matches. Needs both
/// toolchains, so it exists only in a `flutter run -d linux` desktop build
/// inside a checkout.
///
/// There used to be a third — the Rust library parsing a *subset* of Himark for
/// itself, so a phone had something. Embedding CPython made it strictly worse
/// than what stood beside it, and it is gone. What that costs is a platform
/// neither backend reaches: iOS today, and a packaged Linux build outside a
/// checkout. Those degrade to a descriptive [MatchRun.error] rather than
/// throwing, exactly as a machine with nothing installed always did.
///
/// A rule goes to the first backend that will **compile** it. No compiler here
/// produces a retryable refusal any more (both are the full compiler, so a rule
/// either compiles or is wrong), but the fall-through is what the list means and
/// is where a third compiler — an iOS one — would arrive.
class HejmarkBridge implements Bridge {
  /// Backends are discovered from disk unless [backends] is given.
  ///
  /// Passing them is how tests reach the dispatch — the one thing this class
  /// does that is neither compiling nor matching — with no toolchain
  /// installed, and it is the same door a future backend comes through.
  HejmarkBridge({List<Backend>? backends}) : _backendsCache = backends;

  /// How long a backend may spend on one rule. The engines' maximal-munch does
  /// not terminate on an unbounded closure (e.g. a bare `{X,&X}` Kleene star),
  /// so a user-authored pattern can hang; the budget turns that into a reported
  /// error instead of a frozen UI.
  static const Duration _findBudget = Duration(seconds: 5);

  Directory? _rootCache;
  bool _rootResolved = false;
  List<Backend>? _backendsCache;

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

  /// The backends reachable here, in preference order. Resolved once: what is
  /// installed does not change while the app runs.
  List<Backend> get _backends {
    final cached = _backendsCache;
    if (cached != null) return cached;
    final backends = <Backend>[];
    // Android only: Chaquopy is an Android Gradle plugin, so nowhere else has
    // an interpreter to answer the channel — and without one the library is an
    // engine with no compiler to pair with, which is no backend at all.
    if (Platform.isAndroid) {
      final native = NativeEngine.instance(root: _root);
      if (native != null) {
        backends.add(embeddedBackend(native, timeout: _findBudget));
      }
    }
    final root = _root;
    final python = _python;
    final findBin = _findBin;
    if (root != null && python != null && findBin != null) {
      backends.add(
        subprocessBackend(
          python: python,
          findBin: findBin,
          root: root,
          timeout: _findBudget,
        ),
      );
    }
    return _backendsCache = backends;
  }

  /// Whether any backend can answer at all.
  bool get available => _backends.isNotEmpty;

  @override
  Future<MatchRun> matchAll(List<Rule> rules, String content) async {
    if (rules.isEmpty || content.isEmpty) return const MatchRun(<MatchRange>[]);
    final backends = _backends;
    if (backends.isEmpty) {
      return const MatchRun(
        <MatchRange>[],
        error:
            'engine unavailable — no embedded compiler on this platform, and '
            'no hejmark checkout to fall back on (needs .venv and '
            'rust/target/debug/find)',
      );
    }

    // Only the first failing rule's message is surfaced, whichever phase it
    // failed in: one line of chrome cannot explain four broken rules anyway.
    String? error;
    final compiled = await _compile(rules, backends, (message) {
      error ??= message;
    });
    final cpSpans = await _match(rules, backends, compiled, content, (message) {
      error ??= message;
    });
    return MatchRun(_resolve(content, cpSpans), error: error);
  }

  /// Hands each rule to the first backend that compiles it.
  ///
  /// Returns the slot's backend index and its program. A retryable refusal
  /// moves to the next backend; a final one stops, because a rule the compiler
  /// calls malformed would be called malformed by every other compiler too.
  /// Either way the *last* refusal is the one reported, which is what puts the
  /// full compiler's diagnosis in front of the device engine's "needs the full
  /// compiler" when both were asked.
  Future<Map<int, (int, String)>> _compile(
    List<Rule> rules,
    List<Backend> backends,
    void Function(String) report,
  ) async {
    final compiled = <int, (int, String)>{};
    for (var slot = 0; slot < rules.length; slot++) {
      CompileRefusal? refused;
      for (var index = 0; index < backends.length; index++) {
        try {
          final program = await backends[index].compiler.compile(
            rules[slot].source,
          );
          compiled[slot] = (index, program);
          refused = null;
          break;
        } on CompileRefusal catch (refusal) {
          refused = refusal;
          if (!refusal.retryable) break;
        }
      }
      if (refused != null) report('${rules[slot].label}: ${refused.message}');
    }
    return compiled;
  }

  /// Runs each backend's engine once over every program it compiled.
  ///
  /// One crossing per backend rather than per rule: a crossing is the expensive
  /// part, and both engines are batched for it.
  Future<List<_Span>> _match(
    List<Rule> rules,
    List<Backend> backends,
    Map<int, (int, String)> compiled,
    String content,
    void Function(String) report,
  ) async {
    final cpSpans = <_Span>[];
    for (var index = 0; index < backends.length; index++) {
      final slots = <int>[
        for (final entry in compiled.entries)
          if (entry.value.$1 == index) entry.key,
      ];
      if (slots.isEmpty) continue;
      final programs = <String>[for (final slot in slots) compiled[slot]!.$2];
      final results = await backends[index].engine.findAll(programs, content);
      for (var i = 0; i < slots.length; i++) {
        final result = results[i];
        final failure = result.error;
        if (failure != null) {
          report('${rules[slots[i]].label}: $failure');
          continue;
        }
        for (final (start, end) in result.spans) {
          cpSpans.add(_Span(start, end, slots[i]));
        }
      }
    }
    return cpSpans;
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

/// One engine hit before resolution: a code-point span plus the slot of the rule
/// that produced it.
class _Span {
  const _Span(this.start, this.end, this.slot);
  final int start;
  final int end;
  final int slot;
}
