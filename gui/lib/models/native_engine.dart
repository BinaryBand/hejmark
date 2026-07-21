import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'backend.dart';

/// How a program fared on the device engine.
enum EngineStatus {
  /// It denoted and matched; [EngineReply.spans] holds the hits.
  ok,

  /// The program is malformed, or the run was unaffordable. There is no third
  /// status: a program has already been through a compiler, so no other
  /// compiler is left to retry it against.
  error,
}

/// One program's outcome from the device engine.
class EngineReply {
  const EngineReply(this.status, {this.message = '', this.spans = const []});

  final EngineStatus status;

  /// Why it failed, for [EngineStatus.error].
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
/// `rust/` is built as a shared library (`libhejmark.so`, one per Android ABI
/// under `android/app/src/main/jniLibs/`) carrying `rust/src/ffi.rs`, and this
/// class calls into it directly — no subprocess, no toolchain on the machine.
///
/// **It compiles nothing.** Programs arrive as floor-AST JSON some real
/// compiler already produced, which is the same shape the `find` binary reads,
/// and the library denotes and matches it without parsing any Himark. So this
/// gives up no coverage at all: whatever the paired [Compiler] can lower, this
/// can run. The compiler is where a platform's limits live now, and the only
/// one that reaches a phone is the CPython embedded beside this library
/// (`embedded_backend.dart`).
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
        DynamicLibrary.open(candidate).lookup<NativeFunction<_FindC>>(
          'hejmark_find_json',
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

  /// Runs every compiled program in [programs] over [content] on a background
  /// isolate.
  ///
  /// Each program is floor-AST JSON, exactly as `hejmark emit-json` writes it.
  /// Returns one reply per program, in order. A [timeout] abandons the wait; the
  /// isolate itself keeps going until the engine's own budget stops it, which is
  /// why this reports rather than cancels.
  Future<List<EngineReply>> findAll(
    List<String> programs,
    String content, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (programs.isEmpty) return const <EngineReply>[];
    final path = libraryPath;
    try {
      final replies = await Isolate.run(
        () => _findAllSync(path, programs, content),
      ).timeout(timeout);
      return replies.map(EngineReply.parse).toList();
    } on TimeoutException {
      return List<EngineReply>.filled(
        programs.length,
        const EngineReply(
          EngineStatus.error,
          message: 'pattern too complex (engine timed out)',
        ),
      );
    } on Object catch (e) {
      return List<EngineReply>.filled(
        programs.length,
        EngineReply(EngineStatus.error, message: 'engine error: $e'),
      );
    }
  }
}

/// Runs compiled programs over the C ABI, on a background isolate.
///
/// The [Engine] half of every [Backend] that reaches this library, whichever
/// [Compiler] produced the programs — the pairing is a property of the backend,
/// not of the engine, and the only thing this asks of a compiler is floor-AST
/// JSON.
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
          EngineStatus.error => EngineResult.failed(reply.message),
        },
    ];
  }
}

/// The isolate body: open the library, run every program, hand back raw replies.
///
/// Replies cross as strings because that is trivially sendable and keeps the
/// parsing — and any future protocol change — on one side of the boundary.
List<String> _findAllSync(String path, List<String> programs, String content) {
  final symbols = _Symbols.open(path);
  final target = content.toNativeUtf8();
  try {
    return <String>[
      for (final program in programs)
        () {
          final query = program.toNativeUtf8();
          try {
            return symbols.take(symbols.find(query, target));
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
typedef _FreeC = Void Function(Pointer<Utf8> text);
typedef _FreeDart = void Function(Pointer<Utf8> text);

/// The C entry points, bound in whichever isolate needs them.
class _Symbols {
  _Symbols(this.find, this._free);

  factory _Symbols.open(String path) {
    final library = DynamicLibrary.open(path);
    return _Symbols(
      library.lookupFunction<_FindC, _FindC>('hejmark_find_json'),
      library.lookupFunction<_FreeC, _FreeDart>('hejmark_string_free'),
    );
  }

  /// A compiled floor AST in, parsed by nothing — it is already the AST.
  final _FindC find;

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
