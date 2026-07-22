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

  /// The five `html-escape` statements `AppState` seeds, in order. A statement
  /// finds by its *query*, so each answers the one character it escapes.
  static const List<String> escapeRules = <String>[
    r'{\&} => "&amp;"',
    r'{\<} => "&lt;"',
    r'{>} => "&gt;"',
    r'{\"} => "&quot;"',
    '''{'} => "&#39;"''',
  ];

  /// Literal hits per rule source, keyed by the sources `AppState` seeds.
  static const Map<String, List<String>>
  tokensBySource = <String, List<String>>{
    r'{\&} => "&amp;"': <String>['&'],
    r'{\<} => "&lt;"': <String>['<'],
    r'{>} => "&gt;"': <String>['>'],
    r'{\"} => "&quot;"': <String>['"'],
    '''{'} => "&#39;"''': <String>["'"],
    // markdown-to-html's two inline statements, over its seeded note.
    r'{*}{@emBody}{*} => "<b>{{$2}}</b>"': <String>['*pointed*'],
    r'{`}{@codeBody}{`} => "<code>{{$2}}</code>"': <String>['`{a}&{b}`'],
  };

  /// Literal rewrites per script source, keyed on the joined enabled-rule
  /// sources `AppState` sends. Anything unlisted comes back unchanged, which
  /// is what the real engine does for a script of bare queries — they refine
  /// and write nothing.
  ///
  /// The `html-escape` answer is **verbatim from the real engine** — the Rust
  /// `run` binary over `hejmark emit-program`'s output for those five rules and
  /// that test string — so the flows assert against what the app really shows.
  static final Map<String, String> documentsByScript = <String, String>{
    escapeRules.join('\n'):
        'Tom &amp; Jerry&#39;s &lt;b&gt;show&lt;/b&gt;\n'
        'if (a &lt; b &amp;&amp; c &gt; d) { say(&quot;hi&quot;); }',
    // The flows' one hand-written script: swap every a for a b.
    '{a} => "b"': 'rewritten',
  };

  @override
  Future<DocumentRun> runScript(String source, String content) async {
    return DocumentRun(documentsByScript[source] ?? content);
  }

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
