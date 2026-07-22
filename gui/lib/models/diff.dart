import 'matcher.dart';

/// The slot a rewrite span wears instead of a rule position.
///
/// A rewrite belongs to the *script*, not to any one rule: a contracting
/// statement rewrites the same region repeatedly and a later statement may write
/// over an earlier one's output, so attributing an output region to one rule
/// would be a guess. It gets its own colour instead, and the negative value is
/// what keeps it out of `HimarkTokens.ruleColorAt`'s cycle.
const int kRewriteSlot = -1;

/// Above this many differing code units on either side the diff stops resolving
/// and answers one span over the whole changed stretch. A script that rewrites a
/// large document wholesale has nothing useful to say per-region anyway, and the
/// quadratic table below must not be what decides whether a frame lands.
const int _diffLimit = 1200;

/// Where [after] differs from [before], as spans over **[after]**.
///
/// Both arguments are Dart strings and both offsets are UTF-16 code units, so
/// none of `bridge.dart`'s code-point conversion applies here — these spans are
/// already in the units `Text.rich` indexes.
///
/// The result is the output side of the edit script: an insertion is the
/// inserted text's span, a replacement is the replacing text's span, and a pure
/// deletion contributes nothing, because there is no text left in [after] to
/// paint. Spans arrive in ascending order and never touch.
List<MatchRange> rewriteSpans(String before, String after) {
  if (identical(before, after) || before == after) return const <MatchRange>[];

  // Trim what both ends agree on; the interesting edit is between.
  var head = 0;
  final headMax = before.length < after.length ? before.length : after.length;
  while (head < headMax && before.codeUnitAt(head) == after.codeUnitAt(head)) {
    head++;
  }
  var tail = 0;
  final tailMax = headMax - head;
  while (tail < tailMax &&
      before.codeUnitAt(before.length - 1 - tail) ==
          after.codeUnitAt(after.length - 1 - tail)) {
    tail++;
  }

  final a = before.substring(head, before.length - tail);
  final b = after.substring(head, after.length - tail);
  if (b.isEmpty) return const <MatchRange>[]; // a pure deletion paints nothing
  if (a.isEmpty || a.length > _diffLimit || b.length > _diffLimit) {
    return <MatchRange>[
      MatchRange(head, head + b.length, b, slot: kRewriteSlot),
    ];
  }

  return _spansOf(after, head, _keptInB(a, b));
}

/// For each position of `b`, whether it survives as a common subsequence with
/// `a` — the complement being what the script wrote.
///
/// A plain LCS table: the strings here are one document's changed stretch, and
/// [_diffLimit] bounds the product before we arrive.
List<bool> _keptInB(String a, String b) {
  final table = List<List<int>>.generate(
    a.length + 1,
    (_) => List<int>.filled(b.length + 1, 0),
    growable: false,
  );
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      table[i][j] = a.codeUnitAt(i) == b.codeUnitAt(j)
          ? table[i + 1][j + 1] + 1
          : (table[i + 1][j] >= table[i][j + 1]
                ? table[i + 1][j]
                : table[i][j + 1]);
    }
  }

  final kept = List<bool>.filled(b.length, false);
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    if (a.codeUnitAt(i) == b.codeUnitAt(j)) {
      kept[j] = true;
      i++;
      j++;
    } else if (table[i + 1][j] >= table[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return kept;
}

/// Gather the runs [kept] marks as written into spans over [after], offset by
/// the common head [base].
List<MatchRange> _spansOf(String after, int base, List<bool> kept) {
  final spans = <MatchRange>[];
  var run = -1;
  for (var j = 0; j <= kept.length; j++) {
    final written = j < kept.length && !kept[j];
    if (written && run < 0) {
      run = j;
    } else if (!written && run >= 0) {
      final start = base + run;
      final end = base + j;
      spans.add(
        MatchRange(start, end, after.substring(start, end), slot: kRewriteSlot),
      );
      run = -1;
    }
  }
  return spans;
}
