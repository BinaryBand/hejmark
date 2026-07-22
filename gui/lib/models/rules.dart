import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// One coloured run of a rule's Himark source.
@immutable
class CodeSpan {
  const CodeSpan(this.text, this.color);
  final String text;
  final Color color;
}

/// Tokenises a rule's real Himark [source] into coloured runs for display.
///
/// This is a display-only lexer — it never has to be exact, only readable — so
/// it classifies char by char: structure (`{ } [ ]` and `,`) takes [brace];
/// `@name` splices, `\x` escapes, `^n` exponents, digit/range values, and the
/// `! & _` operators each take their own [SyntaxColors] colour; anything else
/// (a literal face character) reads as an identifier.
///
/// [syntax] rides the active theme rather than being fixed, so the same rule
/// stays legible on `airy`'s near-white surface and `ocean`'s near-black one.
List<CodeSpan> spansFor(String source, Color brace, SyntaxColors syntax) {
  final spans = <CodeSpan>[];
  void emit(String text, Color color) {
    if (text.isEmpty) return;
    // Coalesce adjacent runs of the same colour so the RichText stays compact.
    if (spans.isNotEmpty && spans.last.color == color) {
      final prev = spans.removeLast();
      spans.add(CodeSpan(prev.text + text, color));
    } else {
      spans.add(CodeSpan(text, color));
    }
  }

  var i = 0;
  while (i < source.length) {
    final ch = source[i];
    if (ch == '{' || ch == '}' || ch == '[' || ch == ']' || ch == ',') {
      emit(ch, brace);
      i++;
    } else if (ch == r'\' && i + 1 < source.length) {
      emit(source.substring(i, i + 2), syntax.escape);
      i += 2;
    } else if (ch == '@') {
      var j = i + 1;
      while (j < source.length && _isLetter(source[j])) {
        j++;
      }
      emit(source.substring(i, j), syntax.identifier);
      i = j;
    } else if (ch == '^') {
      var j = i + 1;
      while (j < source.length && _isDigit(source[j])) {
        j++;
      }
      emit(source.substring(i, j), syntax.quantifier);
      i = j;
    } else if (_isDigit(ch) || ch == '.') {
      var j = i;
      while (j < source.length && (_isDigit(source[j]) || source[j] == '.')) {
        j++;
      }
      emit(source.substring(i, j), syntax.value);
      i = j;
    } else if (ch == '!' || ch == '&' || ch == '_') {
      emit(ch, syntax.special);
      i++;
    } else {
      emit(ch, syntax.identifier);
      i++;
    }
  }
  return spans;
}

bool _isLetter(String ch) {
  final c = ch.codeUnitAt(0);
  return (c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a);
}

bool _isDigit(String ch) {
  final c = ch.codeUnitAt(0);
  return c >= 0x30 && c <= 0x39;
}
