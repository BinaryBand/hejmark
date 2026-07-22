import 'package:shared_preferences/shared_preferences.dart';

/// Where a session's work is kept between runs.
///
/// The whole of [AppState]'s persistent shape is one JSON string, so this is a
/// single-slot key/value store and nothing more. Keeping it an interface is
/// what lets a test hand [AppState] a [MemoryStore] and drive a round trip
/// without a platform channel under it.
abstract class Store {
  Future<String?> load();
  Future<void> save(String data);
}

/// The real one: `shared_preferences`, which is a file under the app's data
/// directory on Android and under `$XDG_DATA_HOME` on Linux.
///
/// **Every call is defensive**, and that is the design rather than a hedge:
/// the plugin is absent in `flutter test` (no binary messenger answers its
/// channel) and can be absent in a stripped desktop build, and neither is a
/// reason for the editor to fail to open. A store that cannot load reads as a
/// first run; a store that cannot save loses the session and nothing else.
class PrefsStore implements Store {
  const PrefsStore({this.key = 'himark-editor.session'});

  final String key;

  @override
  Future<String?> load() async {
    try {
      return (await SharedPreferences.getInstance()).getString(key);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(String data) async {
    try {
      await (await SharedPreferences.getInstance()).setString(key, data);
    } on Object {
      return;
    }
  }
}

/// An in-memory [Store] for tests: survives a rebuild of [AppState], not a
/// rebuild of the process.
class MemoryStore implements Store {
  MemoryStore([this.data]);

  String? data;

  @override
  Future<String?> load() async => data;

  @override
  Future<void> save(String value) async => data = value;
}
