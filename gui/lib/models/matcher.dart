import 'project.dart';
import 'rules.dart';

/// A resolved match span over the test string.
class MatchRange {
  const MatchRange(this.start, this.end, this.text);
  final int start;
  final int end;
  final String text;
}

/// Runs every enabled rule over [content], sorts hits by start offset and drops
/// overlaps (first-wins). Verbatim port of the brief's `computeMatches`.
List<MatchRange> computeMatches(
  String content,
  List<Rule> rules,
  Map<String, bool> enabled,
) {
  final ranges = <MatchRange>[];
  for (final r in rules) {
    if (!(enabled[r.id] ?? false)) continue;
    final re = ruleRegExp(r.kind);
    if (re == null) continue;
    for (final m in re.allMatches(content)) {
      final text = m.group(0) ?? '';
      if (text.isEmpty) continue;
      ranges.add(MatchRange(m.start, m.start + text.length, text));
    }
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

/// 1-based `line:col` of an offset. Verbatim port of the brief's `posOf`.
String posOf(String content, int idx) {
  var line = 1;
  var col = 1;
  for (var i = 0; i < idx && i < content.length; i++) {
    if (content[i] == '\n') {
      line++;
      col = 1;
    } else {
      col++;
    }
  }
  return '$line:$col';
}
