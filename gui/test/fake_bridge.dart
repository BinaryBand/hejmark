import 'package:himark_editor/models/bridge.dart';
import 'package:himark_editor/models/matcher.dart';
import 'package:himark_editor/models/project.dart';

/// A synchronous stand-in for [HejmarkBridge] so widget flows stay deterministic
/// without spawning the Python parser and Rust engine.
///
/// It answers per rule, matching each seeded source's tokens verbatim — the same
/// hits the real engine returns for them — and tags each hit with the slot of
/// the rule that made it. Because it keys on the rule rather than the content,
/// switching a rule off really does drop its hits, which is what the flows
/// assert against.
class FakeBridge implements Bridge {
  const FakeBridge();

  static const String _octet = r'{{0..9}^3,{0..9}^2,{0..9}}';
  static const String _ipv4 = '$_octet{\\.}$_octet{\\.}$_octet{\\.}$_octet';

  /// Literal hits per rule source, keyed by the sources `AppState` seeds.
  static const Map<String, List<String>> tokensBySource =
      <String, List<String>>{
        _ipv4: <String>['192.168.1.42', '10.0.0.1', '10.2.3.4', '10.0.0.2'],
        r'{\#}{@hex}^6': <String>['#ff8800', '#1e90ff', '#00ffcc'],
        r'{0..9}^4': <String>['4821', '2048'],
      };

  @override
  Future<MatchRun> matchAll(List<Rule> rules, String content) async {
    if (rules.isEmpty || content.isEmpty) return const MatchRun(<MatchRange>[]);
    final hits = <MatchRange>[];
    for (var slot = 0; slot < rules.length; slot++) {
      final tokens = tokensBySource[rules[slot].source] ?? const <String>[];
      for (final token in tokens) {
        final at = content.indexOf(token);
        if (at >= 0) {
          hits.add(MatchRange(at, at + token.length, token, slot: slot));
        }
      }
    }
    hits.sort((a, b) => a.start.compareTo(b.start));

    // The same first-wins overlap resolution the real bridge applies.
    final merged = <MatchRange>[];
    var lastEnd = -1;
    for (final hit in hits) {
      if (hit.start >= lastEnd) {
        merged.add(hit);
        lastEnd = hit.end;
      }
    }
    return MatchRun(merged);
  }
}
