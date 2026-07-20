import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import 'project.dart';

/// Human label shown above a rule's code. Mirrors `RULE_LABEL`.
String ruleLabel(RuleKind kind) {
  switch (kind) {
    case RuleKind.email:
      return 'Slug or handle';
    case RuleKind.ipv4:
      return 'IPv4 address';
    case RuleKind.heading:
      return 'Fenced heading block';
    case RuleKind.custom:
      return 'Custom pattern';
  }
}

/// One coloured run of a rule's Himark source.
@immutable
class CodeSpan {
  const CodeSpan(this.text, this.color);
  final String text;
  final Color color;
}

/// The syntax-highlighted spelling of each rule kind. Mirrors `RULE_SPANS`;
/// [brace] is the token colour used for structural braces (onSurfaceVariant).
List<CodeSpan> ruleSpans(RuleKind kind, Color brace) {
  switch (kind) {
    case RuleKind.email:
      return <CodeSpan>[
        CodeSpan('{', brace),
        const CodeSpan('@l,@d,.,_,-', Syntax.identifier),
        CodeSpan('}', brace),
        const CodeSpan('[1..]', Syntax.quantifier),
        CodeSpan('{', brace),
        const CodeSpan('@', Syntax.value),
        CodeSpan('}', brace),
        CodeSpan('{', brace),
        const CodeSpan('@l,@d,-', Syntax.identifier),
        CodeSpan('}', brace),
        const CodeSpan('[1..]', Syntax.quantifier),
        CodeSpan('{.}{', brace),
        const CodeSpan('@l', Syntax.identifier),
        CodeSpan('}', brace),
        const CodeSpan('[2..]', Syntax.quantifier),
      ];
    case RuleKind.ipv4:
      return <CodeSpan>[
        CodeSpan('{', brace),
        const CodeSpan('@d::0..255', Syntax.value),
        CodeSpan('}{.}{', brace),
        const CodeSpan('@d::0..255', Syntax.value),
        CodeSpan('}{.}{', brace),
        const CodeSpan('@d::0..255', Syntax.value),
        CodeSpan('}{.}{', brace),
        const CodeSpan('@d::0..255', Syntax.value),
        CodeSpan('}', brace),
      ];
    case RuleKind.heading:
      return <CodeSpan>[
        CodeSpan('{@<}{', brace),
        const CodeSpan('#', Syntax.special),
        CodeSpan('}', brace),
        const CodeSpan('[1..6]', Syntax.quantifier),
        CodeSpan('{ }', brace),
        const CodeSpan('[1..]', Syntax.quantifier),
        CodeSpan('!{', brace),
        const CodeSpan(r'\n', Syntax.escape),
        CodeSpan('}', brace),
        const CodeSpan('[1..]', Syntax.quantifier),
        CodeSpan('{@>}', brace),
      ];
    case RuleKind.custom:
      return <CodeSpan>[
        CodeSpan('{', brace),
        const CodeSpan('@l,@d', Syntax.identifier),
        CodeSpan('}', brace),
        const CodeSpan('[1..]', Syntax.quantifier),
      ];
  }
}

/// The regex approximation each rule matches with. Mirrors `RULE_RE`. `custom`
/// has no matcher (returns null), exactly as the brief.
RegExp? ruleRegExp(RuleKind kind) {
  switch (kind) {
    case RuleKind.email:
      return RegExp(r'[\w.\-]+@[\w\-]+\.[A-Za-z][\w.]*');
    case RuleKind.ipv4:
      return RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b');
    case RuleKind.heading:
      return RegExp(r'^#{1,6}\s.+$', multiLine: true);
    case RuleKind.custom:
      return null;
  }
}
