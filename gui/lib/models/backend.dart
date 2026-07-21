/// Lowers Himark source to a *program* — whatever the paired [Engine] reads.
///
/// This is one half of the seam. Cutting the bridge here rather than at the run
/// is what makes the two halves swappable: an engine serves any compiler that
/// emits the program shape it reads, so moving the compiler on-device
/// (`docs/TODO.md`) changes which [Compiler] is constructed and nothing else.
///
/// A program is an opaque string, and **which** string is a property of the
/// pair rather than of this interface. In practice every pair now agrees on one
/// shape — floor-AST JSON, as `hejmark emit-json` writes it — so a compiler and
/// an engine here really are interchangeable across [Backend]s, which is what
/// lets `embedded_backend.dart` put the device's compiler in front of the same
/// [Engine] the desktop uses. That is a fact about today's implementations, not
/// a promise this interface makes.
abstract interface class Compiler {
  /// Lowers [source] to a program, or throws [CompileRefusal].
  ///
  /// Implementations cache by source: a rule is recompiled only when edited,
  /// which is what keeps a keystroke in the test pane off the compiler.
  Future<String> compile(String source);
}

/// Runs compiled programs over text — the other half of the seam.
abstract interface class Engine {
  /// Matches each of [programs] against [text], one result per program in
  /// order.
  ///
  /// Batched rather than per-program because a crossing is the expensive part:
  /// the device engine takes every rule over one isolate hop, and the
  /// subprocess engine writes the target file once for all of them.
  ///
  /// Spans come back as **code-point** offsets, exactly as both engines emit
  /// them; converting to UTF-16 is the caller's job.
  Future<List<EngineResult>> findAll(List<String> programs, String text);
}

/// A compiler and the engine that reads what it produces.
///
/// Held as a pair because that is the unit a rule is dispatched to: the bridge
/// walks its backends in preference order and the first one that *compiles* a
/// rule also matches it. See [Compiler] for why the pairing is not yet free.
class Backend {
  const Backend({required this.compiler, required this.engine});

  final Compiler compiler;
  final Engine engine;
}

/// Thrown by a [Compiler] that will not compile a rule.
class CompileRefusal implements Exception {
  const CompileRefusal(this.message, {this.retryable = false});

  /// Why, in words fit to show a user.
  final String message;

  /// Whether another compiler might succeed where this one refused.
  ///
  /// `false` means the rule is wrong and every compiler would refuse it, which
  /// is what both compilers shipping today report: each is the whole compiler,
  /// so there is nothing behind it. The flag survives because it is the only
  /// thing that makes a *list* of backends more than a list of one, and because
  /// a partial compiler on a platform neither reaches would need it — carried as
  /// a flag rather than a message, so the retry decision is never a string
  /// comparison.
  final bool retryable;

  @override
  String toString() => message;
}

/// One program's outcome from an [Engine]: the hits, or why there are none.
class EngineResult {
  const EngineResult(this.spans, {this.error});

  const EngineResult.failed(String this.error) : spans = const <(int, int)>[];

  /// The hits as `(start, end)` code-point offsets.
  final List<(int, int)> spans;

  /// Set when the engine could not answer — a timeout, a crash, a refusal from
  /// the work budget. Never set for a rule that simply matched nothing.
  final String? error;
}
