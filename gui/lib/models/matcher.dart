/// A resolved match span over the test string. Offsets are UTF-16, consistent
/// with Dart string indexing; the bridge converts the engine's code-point
/// offsets before constructing these.
class MatchRange {
  const MatchRange(this.start, this.end, this.text);
  final int start;
  final int end;
  final String text;
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
