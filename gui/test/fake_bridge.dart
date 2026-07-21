import 'package:himark_editor/models/bridge.dart';
import 'package:himark_editor/models/matcher.dart';
import 'package:himark_editor/models/project.dart';

/// A synchronous stand-in for [HejmarkBridge] so widget flows stay deterministic
/// without spawning the Python parser and Rust engine. It reports the seeded
/// demo tokens it finds verbatim in the content — the same hits the real engine
/// returns for the seeded IPv4 and hex-colour rules.
class FakeBridge implements Bridge {
  const FakeBridge();

  static const List<String> _tokens = <String>[
    '192.168.1.42',
    '10.0.0.1',
    '#ff8800',
    '#1e90ff',
  ];

  @override
  Future<MatchRun> matchAll(List<Rule> rules, String content) async {
    if (rules.isEmpty || content.isEmpty) return const MatchRun(<MatchRange>[]);
    final out = <MatchRange>[];
    for (final token in _tokens) {
      final at = content.indexOf(token);
      if (at >= 0) out.add(MatchRange(at, at + token.length, token));
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return MatchRun(out);
  }
}
