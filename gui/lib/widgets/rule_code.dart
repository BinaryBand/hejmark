import 'package:flutter/material.dart';

import '../models/rules.dart';
import '../theme/tokens.dart';

/// Renders a rule's Himark source as syntax-highlighted monospace text inside a
/// rounded surface, wrapping on any character.
class RuleCode extends StatelessWidget {
  const RuleCode({
    required this.spans,
    required this.fontSize,
    required this.tokens,
    super.key,
  });

  final List<CodeSpan> spans;
  final double fontSize;
  final HimarkTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.surfaceContainer,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            for (final span in spans)
              TextSpan(
                text: span.text,
                style: mono(fontSize: fontSize, color: span.color, height: 1.6),
              ),
          ],
        ),
      ),
    );
  }
}
