import 'package:flutter/widgets.dart';

/// Material-3 style token set, transcribed verbatim from the Himark GUI design.
/// The instances live in `schemes.dart` — three schemes (ocean, airy, joplin)
/// each with a dark and a light face — and `tokensFor` is the only way to
/// reach one.
@immutable
class HimarkTokens {
  const HimarkTokens({
    required this.surface,
    required this.surfaceDim,
    required this.surfaceBright,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.outline,
    required this.outlineVariant,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.tertiary,
    required this.ruleColors,
    required this.syntax,
  });

  final Color surface;
  final Color surfaceDim;
  final Color surfaceBright;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color outline;
  final Color outlineVariant;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color tertiary;

  /// The scheme's `RULE_COLORS` palette: one [RuleColors] per rule, cycled by
  /// the rule's position in the project unless the rule pins a swatch.
  final List<RuleColors> ruleColors;

  /// The colours a rule's Himark source is highlighted with. Theme-dependent
  /// rather than fixed, because the light faces of `airy` and `joplin` are far
  /// brighter than the original's and washed the dark-tuned hexes out.
  final SyntaxColors syntax;

  /// The colours a rule at [index] paints with, wrapping past the palette's end.
  RuleColors ruleColorAt(int index) =>
      ruleColors[index.remainder(ruleColors.length)];
}

/// The three colours one rule paints with: [dot] marks it in the rules list and
/// bullets its hits in the output sheet, [background] and [foreground] highlight
/// the spans it matched in the read view.
///
/// The design keys these by rule kind (`email`, `ipv4`, `heading`, `custom`) and
/// its `markBg`/`markFg` tokens are exactly the `custom` slot, so they have no
/// separate existence here. Rules carry no kind in this app, so the palette is
/// cycled by list position instead — same four slots, same order.
@immutable
class RuleColors {
  const RuleColors({
    required this.dot,
    required this.background,
    required this.foreground,
  });

  final Color dot;
  final Color background;
  final Color foreground;
}

/// Syntax-highlight palette used when rendering a rule's Himark code.
@immutable
class SyntaxColors {
  const SyntaxColors({
    required this.identifier,
    required this.quantifier,
    required this.value,
    required this.special,
    required this.escape,
  });

  final Color identifier; // @l, @d
  final Color quantifier; // [1..]
  final Color value; // @, @d::0..255
  final Color special; // #
  final Color escape; // \n
}

/// Shared monospace text family. Prefers Roboto Mono (the design's font, present
/// on mobile), falling back to fonts installed on Linux/macOS/Windows so the app
/// needs no bundled font files.
const String kMonoFamily = 'Roboto Mono';
const List<String> kMonoFallback = <String>[
  'Noto Sans Mono',
  'DejaVu Sans Mono',
  'Menlo',
  'Consolas',
  'monospace',
];

/// Shared sans family and fallback, mirroring the design's Roboto with clean
/// cross-platform substitutes.
const String kSansFamily = 'Roboto';
const List<String> kSansFallback = <String>[
  'Noto Sans',
  'DejaVu Sans',
  'Helvetica Neue',
  'Arial',
  'sans-serif',
];

TextStyle mono({
  required double fontSize,
  required Color color,
  FontWeight fontWeight = FontWeight.w400,
  double height = 1.7,
}) {
  return TextStyle(
    fontFamily: kMonoFamily,
    fontFamilyFallback: kMonoFallback,
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    height: height,
  );
}
