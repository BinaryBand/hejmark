import 'package:flutter/services.dart';

import 'backend.dart';
import 'native_engine.dart';

/// The channel `MainActivity.kt` answers on. Two methods, `compile` (a rule to
/// floor-AST JSON) and `compileProgram` (a script to Program JSON).
const MethodChannel embeddedChannel = MethodChannel('dev.himark.editor/compiler');

/// The phone's full backend: the **real** compiler, embedded, over the Rust
/// engine already linked beside it.
///
/// This is the device's only compiler, and it is the whole language: `hejmark`'s
/// own ANTLR parser and L1.5 expansion, running on CPython embedded in the app
/// (Chaquopy, configured in `android/app/build.gradle.kts`), with no toolchain
/// and no network. There used to be a partial Rust front end here for the floor
/// subset; it was deleted once this could compile everything it could and more.
///
/// The pair is what makes it work: the program is floor-AST JSON, the same
/// hand-off the desktop's subprocess path uses, and [FfiEngine] takes it
/// straight to `hejmark_find_json`. So the compiler moved and the engine did
/// not — matching stays in Rust, where the battery cares.
///
/// Android only: Chaquopy is an Android Gradle plugin, so on every other
/// platform the channel has nobody on the other end and [EmbeddedCompiler]
/// refuses rather than throwing.
Backend embeddedBackend(
  NativeEngine engine, {
  required Duration timeout,
  MethodChannel channel = embeddedChannel,
}) => Backend(
  compiler: EmbeddedCompiler(channel),
  engine: FfiEngine(engine, timeout: timeout),
);

/// Compiles on the device by calling the embedded interpreter.
class EmbeddedCompiler implements Compiler {
  EmbeddedCompiler(this._channel);

  final MethodChannel _channel;

  /// Outcome by source, one map per program shape: the JSON where it
  /// compiled, the refusal otherwise.
  ///
  /// Cached both ways, like every other [Compiler] here — the answer cannot
  /// change while the source does not, and a keystroke in the test pane should
  /// not cross the platform channel to re-learn it. Separate maps because the
  /// same text answers differently as a query and as a script.
  final Map<String, Object> _queryOutcomes = <String, Object>{};
  final Map<String, Object> _scriptOutcomes = <String, Object>{};

  @override
  Future<String> compile(String source) =>
      _cached(_queryOutcomes, 'compile', source);

  @override
  Future<String> compileScript(String source) =>
      _cached(_scriptOutcomes, 'compileProgram', source);

  Future<String> _cached(
    Map<String, Object> outcomes,
    String method,
    String source,
  ) async {
    final outcome = outcomes[source] ?? await _invoke(method, source);
    outcomes[source] = outcome;
    if (outcome is CompileRefusal) throw outcome;
    return outcome as String;
  }

  Future<Object> _invoke(String method, String source) async {
    final String reply;
    try {
      reply =
          await _channel.invokeMethod<String>(method, <String, String>{
            'source': source,
          }) ??
          '';
    } on PlatformException catch (error) {
      // The channel itself failed — no handler registered, or the platform
      // side threw before it could form a reply. Not retryable in the sense
      // the bridge means: nothing about the *rule* is wrong.
      return CompileRefusal(error.message ?? 'the embedded compiler failed');
    } on MissingPluginException {
      return const CompileRefusal('no embedded compiler on this platform');
    }
    // The status-line-then-body shape `rust/src/ffi.rs` defines, reused so the
    // two halves of the device path answer alike. Every refusal here is final:
    // this is the full compiler, so nothing further could take the rule.
    final split = reply.indexOf('\n');
    final status = split < 0 ? reply : reply.substring(0, split);
    final body = split < 0 ? '' : reply.substring(split + 1);
    if (status == 'ok') return body.trim();
    final message = body.trim();
    return CompileRefusal(message.isEmpty ? 'the rule could not be compiled' : message);
  }
}
