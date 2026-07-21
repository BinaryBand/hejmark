import 'package:flutter/services.dart';

import 'backend.dart';
import 'native_backend.dart';
import 'native_engine.dart';

/// The channel `MainActivity.kt` answers on. One method, `compile`.
const MethodChannel embeddedChannel = MethodChannel('dev.himark.editor/compiler');

/// The phone's full backend: the **real** compiler, embedded, over the Rust
/// engine already linked beside it.
///
/// This is the one that retires the device's compiler gap. `nativeBackend`
/// compiles the floor subset `rust/src/surface/parse.rs` reads and refuses a
/// pipeline or a back-reference as `unported`; this one runs `hejmark`'s own
/// ANTLR parser and L1.5 expansion on CPython embedded in the app (Chaquopy,
/// configured in `android/app/build.gradle.kts`), so every construct the
/// language has compiles on a device with no toolchain and no network.
///
/// The pair is what makes it work: the program is floor-AST JSON, the same
/// hand-off the desktop's subprocess path uses, and [FfiEngine] takes it
/// straight to `hejmark_find_json`. So the compiler moved and the engine did
/// not — matching stays in Rust, where the battery cares.
///
/// Android only: Chaquopy is an Android Gradle plugin, so on every other
/// platform the channel has nobody on the other end. [available] is how the
/// bridge asks rather than assuming.
Backend embeddedBackend(
  NativeEngine engine, {
  required Duration timeout,
  MethodChannel channel = embeddedChannel,
}) => Backend(
  compiler: EmbeddedCompiler(channel),
  engine: FfiEngine(engine, timeout: timeout, compiled: true),
);

/// Compiles on the device by calling the embedded interpreter.
class EmbeddedCompiler implements Compiler {
  EmbeddedCompiler(this._channel);

  final MethodChannel _channel;

  /// Outcome by source: the JSON where it compiled, the refusal otherwise.
  ///
  /// Cached both ways, like every other [Compiler] here — the answer cannot
  /// change while the source does not, and a keystroke in the test pane should
  /// not cross the platform channel to re-learn it.
  final Map<String, Object> _outcomes = <String, Object>{};

  @override
  Future<String> compile(String source) async {
    final outcome = _outcomes[source] ?? await _compile(source);
    _outcomes[source] = outcome;
    if (outcome is CompileRefusal) throw outcome;
    return outcome as String;
  }

  Future<Object> _compile(String source) async {
    final String reply;
    try {
      reply =
          await _channel.invokeMethod<String>('compile', <String, String>{
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
    // The reply shape `rust/src/ffi.rs` defines, reused so both device paths
    // answer alike. `unported` cannot appear: this is the full compiler, so its
    // refusals are final and there is nothing further to retry against.
    final split = reply.indexOf('\n');
    final status = split < 0 ? reply : reply.substring(0, split);
    final body = split < 0 ? '' : reply.substring(split + 1);
    if (status == 'ok') return body.trim();
    final message = body.trim();
    return CompileRefusal(message.isEmpty ? 'the rule could not be compiled' : message);
  }
}
