import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

/// How a rule's source fared on the device engine.
enum EngineStatus {
  /// It parsed and matched; [EngineReply.spans] holds the hits.
  ok,

  /// It is not well-formed Himark, or the run was unaffordable. Retrying
  /// against the full compiler would fail the same way.
  error,

  /// It *is* well-formed Himark, but outside the floor subset this engine
  /// compiles — a pipeline, a back-reference, an unresolvable `@name`. The
  /// Python compiler takes it, so a host that can reach one should retry there.
  unported,
}

/// One rule's outcome from the device engine.
class EngineReply {
  const EngineReply(this.status, {this.message = '', this.spans = const []});

  final EngineStatus status;

  /// Why it failed, for [EngineStatus.error] and [EngineStatus.unported].
  final String message;

  /// The hits as `(start, end)` **code-point** offsets, exactly as the Rust
  /// `find` binary prints them. Callers must convert to UTF-16 themselves.
  final List<(int, int)> spans;

  /// Reads the reply format `src/ffi.rs` documents: a status line, then a body.
  factory EngineReply.parse(String reply) {
    final split = reply.indexOf('\n');
    final status = split < 0 ? reply : reply.substring(0, split);
    final body = split < 0 ? '' : reply.substring(split + 1);
    switch (status) {
      case 'ok':
        final spans = <(int, int)>[];
        for (final line in const LineSplitter().convert(body)) {
          final parts = line.split('\t');
          if (parts.length != 2) continue;
          final start = int.tryParse(parts[0]);
          final end = int.tryParse(parts[1]);
          if (start != null && end != null) spans.add((start, end));
        }
        return EngineReply(EngineStatus.ok, spans: spans);
      case 'unported':
        return EngineReply(EngineStatus.unported, message: body.trim());
      default:
        final text = body.trim();
        return EngineReply(
          EngineStatus.error,
          message: text.isEmpty ? 'engine error' : text,
        );
    }
  }
}

/// The Himark engine compiled into the app, reached over its C ABI.
///
/// This is the half of the bridge that needs no toolchain. `HejmarkBridge`'s
/// subprocess path runs the real Python compiler and so compiles all of L1.5,
/// but it only exists inside a checkout on a desktop; a phone has neither. So
/// `rust/` is also built as a shared library (`libhejmark.so`, one per Android
/// ABI under `android/app/src/main/jniLibs/`) carrying `rust/src/ffi.rs`, and
/// this class calls into it directly.
///
/// What it gives up is compiler coverage, not engine coverage: the same
/// denotation and the same matcher run, over the *floor subset* of the language
/// that `rust/src/surface/parse.rs` can parse without the ANTLR grammar. A rule
/// outside that subset comes back [EngineStatus.unported] rather than wrong,
/// which is what lets the bridge retry it against Python when Python is there.
///
/// That giving-up is avoidable where a real compiler *is* there. `findAll`'s
/// `compiled` flag takes floor-AST JSON instead of source, which the library
/// denotes without parsing anything — so the app's embedded CPython
/// (`embedded_backend.dart`) compiles the whole language and still matches it
/// here. Same engine, two ways in; only the way in was ever the limit.
///
/// Calls run on a background isolate. The engine's work budget bounds a hard
/// pattern (`rust/src/floor/work.rs`), but "bounded" is millions of membership
/// questions, so a bad rule can still take real time — off the UI thread it
/// costs a slow result instead of a frozen frame.
class NativeEngine {
  NativeEngine._(this.libraryPath);

  /// Where the shared library was found. Held as a path rather than a handle
  /// because the worker isolate must open it for itself — a [DynamicLibrary]
  /// is not sendable.
  final String libraryPath;

  static NativeEngine? _instance;
  static bool _looked = false;

  /// The engine, or null where no library could be loaded.
  ///
  /// Resolved once per session. [root] is the repository root when the app runs
  /// inside a checkout, which is the only way a desktop build finds the library
  /// — Android resolves `libhejmark.so` from the APK by name alone.
  static NativeEngine? instance({Directory? root}) {
    if (_looked) return _instance;
    _looked = true;
    for (final candidate in _candidates(root)) {
      try {
        DynamicLibrary.open(candidate).lookup<NativeFunction<_CheckC>>(
          'hejmark_check',
        );
        _instance = NativeEngine._(candidate);
        return _instance;
      } on Object {
        continue; // not there, or not loadable here: try the next
      }
    }
    return null;
  }

  /// Where to look, in order. Android and the bundled Linux app resolve the
  /// bare name through the normal loader path; a `flutter run -d linux` inside
  /// a checkout falls back to whatever `cargo build` last produced.
  static List<String> _candidates(Directory? root) {
    final names = <String>[
      if (Platform.isWindows) 'hejmark.dll' else if (Platform.isMacOS)
        'libhejmark.dylib'
      else
        'libhejmark.so',
    ];
    final paths = <String>[...names];
    if (root != null) {
      for (final profile in <String>['release', 'debug']) {
        paths.add('${root.path}/rust/target/$profile/${names.first}');
      }
    }
    return paths;
  }

  /// Runs every rule in [sources] over [content] on a background isolate.
  ///
  /// Returns one reply per source, in order. A [timeout] abandons the wait; the
  /// isolate itself keeps going until the engine's own budget stops it, which is
  /// why this reports rather than cancels.
  ///
  /// [compiled] picks the way in. False, each source is Himark this library
  /// parses for itself — the floor subset, and all a host without a compiler
  /// can do. True, each is floor-AST JSON some real compiler already produced,
  /// which is the same shape the `find` binary reads and carries no `unported`
  /// answer, since nothing is left to compile. One engine either way.
  Future<List<EngineReply>> findAll(
    List<String> sources,
    String content, {
    Duration timeout = const Duration(seconds: 5),
    bool compiled = false,
  }) async {
    if (sources.isEmpty) return const <EngineReply>[];
    final path = libraryPath;
    try {
      final replies = await Isolate.run(
        () => _findAllSync(path, sources, content, compiled: compiled),
      ).timeout(timeout);
      return replies.map(EngineReply.parse).toList();
    } on TimeoutException {
      return List<EngineReply>.filled(
        sources.length,
        const EngineReply(
          EngineStatus.error,
          message: 'pattern too complex (engine timed out)',
        ),
      );
    } on Object catch (e) {
      return List<EngineReply>.filled(
        sources.length,
        EngineReply(EngineStatus.error, message: 'engine error: $e'),
      );
    }
  }

  /// Parses one rule without matching, for validation with no text in hand.
  EngineReply check(String source) {
    final symbols = _Symbols.open(libraryPath);
    final query = source.toNativeUtf8();
    try {
      return EngineReply.parse(symbols.take(symbols.check(query)));
    } finally {
      calloc.free(query);
    }
  }
}

/// The isolate body: open the library, run every rule, hand back raw replies.
///
/// Replies cross as strings because that is trivially sendable and keeps the
/// parsing — and any future protocol change — on one side of the boundary.
List<String> _findAllSync(
  String path,
  List<String> sources,
  String content, {
  required bool compiled,
}) {
  final symbols = _Symbols.open(path);
  final entry = compiled ? symbols.findJson : symbols.find;
  final target = content.toNativeUtf8();
  try {
    return <String>[
      for (final source in sources)
        () {
          final query = source.toNativeUtf8();
          try {
            return symbols.take(entry(query, target));
          } finally {
            calloc.free(query);
          }
        }(),
    ];
  } finally {
    calloc.free(target);
  }
}

typedef _FindC =
    Pointer<Utf8> Function(Pointer<Utf8> query, Pointer<Utf8> target);
typedef _CheckC = Pointer<Utf8> Function(Pointer<Utf8> query);
typedef _FreeC = Void Function(Pointer<Utf8> text);
typedef _FreeDart = void Function(Pointer<Utf8> text);

/// The C entry points, bound in whichever isolate needs them.
class _Symbols {
  _Symbols(this.find, this.findJson, this.check, this._free);

  factory _Symbols.open(String path) {
    final library = DynamicLibrary.open(path);
    return _Symbols(
      library.lookupFunction<_FindC, _FindC>('hejmark_find'),
      library.lookupFunction<_FindC, _FindC>('hejmark_find_json'),
      library.lookupFunction<_CheckC, _CheckC>('hejmark_check'),
      library.lookupFunction<_FreeC, _FreeDart>('hejmark_string_free'),
    );
  }

  /// Himark source in, parsed here against the floor subset.
  final _FindC find;

  /// A compiled floor AST in, parsed by nothing — it is already the AST.
  final _FindC findJson;

  final _CheckC check;
  final _FreeDart _free;

  /// Copies a reply out of Rust's memory and releases the original.
  ///
  /// The string was allocated by `CString::into_raw`, so only Rust's allocator
  /// may free it — never `calloc.free`.
  String take(Pointer<Utf8> reply) {
    if (reply == nullptr) return 'err\nthe engine returned nothing';
    try {
      return reply.toDartString();
    } finally {
      _free(reply);
    }
  }
}
