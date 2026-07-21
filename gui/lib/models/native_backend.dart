import 'backend.dart';
import 'native_engine.dart';

/// The device backend: `libhejmark.so` split into its two halves.
///
/// [NativeEngine] is the raw C ABI and stays fused, because `rust/src/ffi.rs`
/// exposes a call that parses *and* matches. The split is recoverable anyway,
/// and without a second parse of anything that matters, because the library
/// also exposes `hejmark_check` — parse this rule, match nothing, tell me how
/// it went. That is exactly a compile step, so [NativeCompiler] is `check` and
/// [FfiEngine] is `find`.
///
/// What the pair does *not* yet have is a program format: `check` reports a
/// verdict rather than emitting anything, so the program [NativeCompiler]
/// returns is the rule source itself, and only [FfiEngine] can read it. See
/// [Compiler] for why that is temporary.
Backend nativeBackend(NativeEngine engine, {required Duration timeout}) =>
    Backend(
      compiler: NativeCompiler(engine),
      engine: FfiEngine(engine, timeout: timeout),
    );

/// Compiles by parsing on the device and keeping the source as the program.
class NativeCompiler implements Compiler {
  NativeCompiler(this._engine);

  final NativeEngine _engine;

  /// Verdict by source: null where the rule compiled, the refusal otherwise.
  ///
  /// Refusals are cached alongside successes on purpose. A rule outside the
  /// floor subset is refused on every keystroke in the test pane otherwise,
  /// and the answer cannot change while the source does not.
  final Map<String, CompileRefusal?> _verdicts = <String, CompileRefusal?>{};

  @override
  Future<String> compile(String source) async {
    if (!_verdicts.containsKey(source)) {
      _verdicts[source] = _verdict(source);
    }
    final refusal = _verdicts[source];
    if (refusal != null) throw refusal;
    return source;
  }

  /// Parses [source] without matching. Synchronous and on this isolate, which
  /// [FfiEngine] deliberately is not: a parse is microseconds where a match is
  /// bounded only by the engine's work budget.
  CompileRefusal? _verdict(String source) {
    final reply = _engine.check(source);
    return switch (reply.status) {
      EngineStatus.ok => null,
      // `unported` is the whole reason a second backend exists: well-formed
      // Himark this engine cannot compile, which the full compiler can.
      EngineStatus.unported => CompileRefusal(reply.message, retryable: true),
      EngineStatus.error => CompileRefusal(reply.message),
    };
  }
}

/// Matches compiled programs over the C ABI, on a background isolate.
class FfiEngine implements Engine {
  FfiEngine(this._engine, {required this.timeout});

  final NativeEngine _engine;

  /// How long to wait on the isolate before reporting the run as too complex.
  final Duration timeout;

  @override
  Future<List<EngineResult>> findAll(List<String> programs, String text) async {
    if (programs.isEmpty) return const <EngineResult>[];
    final replies = await _engine.findAll(programs, text, timeout: timeout);
    return <EngineResult>[
      for (final reply in replies)
        switch (reply.status) {
          EngineStatus.ok => EngineResult(reply.spans),
          // Unreachable: NativeCompiler ran the same parse and would have
          // refused first. Reported rather than asserted, because the two
          // calls crossing the ABI separately is exactly what makes it
          // conceivable — a library swapped under a running app, say.
          EngineStatus.unported ||
          EngineStatus.error => EngineResult.failed(reply.message),
        },
    ];
  }
}
