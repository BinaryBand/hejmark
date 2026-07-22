import 'package:flutter_test/flutter_test.dart';

import 'package:himark_editor/models/diff.dart';

/// The spans as `(start, end, text)` triples, which is what every assertion
/// here is really about.
List<List<Object>> _spans(String before, String after) => <List<Object>>[
  for (final s in rewriteSpans(before, after)) <Object>[s.start, s.end, s.text],
];

void main() {
  test('an unchanged document has nothing to paint', () {
    expect(rewriteSpans('abc', 'abc'), isEmpty);
    expect(rewriteSpans('', ''), isEmpty);
  });

  test('an insertion is the inserted text, positioned in the output', () {
    expect(_spans('ac', 'abc'), <List<Object>>[
      <Object>[1, 2, 'b'],
    ]);
    expect(_spans('', 'hello'), <List<Object>>[
      <Object>[0, 5, 'hello'],
    ]);
  });

  test('a pure deletion paints nothing — no text is left to mark', () {
    expect(rewriteSpans('abc', 'ac'), isEmpty);
    expect(rewriteSpans('hello', ''), isEmpty);
  });

  test('a replacement is the replacing text', () {
    expect(_spans('a&b', 'a&amp;b'), <List<Object>>[
      <Object>[2, 6, 'amp;'],
    ]);
  });

  test('several scattered edits arrive in order and do not touch', () {
    final spans = rewriteSpans('a b c', 'a-X b-Y c');
    expect(spans.length, greaterThan(1));
    var last = -1;
    for (final s in spans) {
      expect(s.start, greaterThanOrEqualTo(last));
      expect(s.end, greaterThan(s.start));
      expect('a-X b-Y c'.substring(s.start, s.end), s.text);
      last = s.end;
    }
  });

  test('an edit at either end is still bounded by the output', () {
    expect(_spans('bc', 'Abc'), <List<Object>>[
      <Object>[0, 1, 'A'],
    ]);
    expect(_spans('ab', 'abZ'), <List<Object>>[
      <Object>[2, 3, 'Z'],
    ]);
  });

  test('every span carries the rewrite slot, never a rule position', () {
    for (final s in rewriteSpans('a<b', 'a&lt;b')) {
      expect(s.slot, kRewriteSlot);
    }
  });

  test('a wholesale rewrite past the resolve limit collapses to one span', () {
    final before = 'a' * 4000;
    final after = 'b' * 4000;
    final spans = rewriteSpans(before, after);
    expect(spans.length, 1);
    expect(spans.first.start, 0);
    expect(spans.first.end, after.length);
  });

  test('the real html-escape rewrite marks exactly the entities', () {
    const before = 'Tom & Jerry';
    const after = 'Tom &amp; Jerry';
    expect(_spans(before, after), <List<Object>>[
      <Object>[5, 9, 'amp;'],
    ]);
  });
}
