/// A resolved match span over the test string. Offsets are UTF-16, consistent
/// with Dart string indexing; the bridge converts the engine's code-point
/// offsets before constructing these.
///
/// [slot] is the position of the rule that produced the hit. The read view and
/// the output sheet turn it into a colour through `HimarkTokens.ruleColorAt`, so
/// two rules matching the same text are told apart by eye.
class MatchRange {
  const MatchRange(this.start, this.end, this.text, {this.slot = 0});
  final int start;
  final int end;
  final String text;
  final int slot;
}

/// 1-based position of an offset, spelled the way the brief's output sheet reads
/// it (`Ln 1 · Col 10`).
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
  return 'Ln $line · Col $col';
}
