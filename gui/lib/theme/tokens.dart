import 'package:flutter/widgets.dart';

/// Material-3 style token set, transcribed verbatim from the Himark GUI design
/// brief (`Himark GUI Redesign.dc.html`). Two frozen instances -- [darkTokens]
/// and [lightTokens] -- are the only sources of colour in the app.
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
    required this.markBg,
    required this.markFg,
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
  final Color markBg;
  final Color markFg;
}

const HimarkTokens darkTokens = HimarkTokens(
  surface: Color(0xFF0C111B),
  surfaceDim: Color(0xFF05070C),
  surfaceBright: Color(0xFF1B2434),
  surfaceContainerLowest: Color(0xFF070A10),
  surfaceContainerLow: Color(0xFF0F1623),
  surfaceContainer: Color(0xFF131C2C),
  surfaceContainerHigh: Color(0xFF1A2436),
  surfaceContainerHighest: Color(0xFF212D42),
  onSurface: Color(0xFFDBE4F0),
  onSurfaceVariant: Color(0xFF93A4BF),
  primary: Color(0xFF5B9BF7),
  onPrimary: Color(0xFF062544),
  primaryContainer: Color(0xFF1E3A5F),
  onPrimaryContainer: Color(0xFFBCD7FF),
  outline: Color(0xFF425169),
  outlineVariant: Color(0xFF1E2736),
  error: Color(0xFFE8828A),
  onError: Color(0xFF4A0D12),
  errorContainer: Color(0xFF4D1A1F),
  onErrorContainer: Color(0xFFF8C6CA),
  tertiary: Color(0xFF98C379),
  markBg: Color(0xFF4A431B),
  markFg: Color(0xFFF4E4A1),
);

const HimarkTokens lightTokens = HimarkTokens(
  surface: Color(0xFFF7F8FB),
  surfaceDim: Color(0xFFC9D0DC),
  surfaceBright: Color(0xFFFFFFFF),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFEEF1F6),
  surfaceContainer: Color(0xFFE7EBF3),
  surfaceContainerHigh: Color(0xFFDDE3EE),
  surfaceContainerHighest: Color(0xFFD2DAE8),
  onSurface: Color(0xFF1A2130),
  onSurfaceVariant: Color(0xFF54637D),
  primary: Color(0xFF2F6FE0),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFD9E6FD),
  onPrimaryContainer: Color(0xFF0D3A78),
  outline: Color(0xFFB7C1D3),
  outlineVariant: Color(0xFFDBE1EC),
  error: Color(0xFFC4342F),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFBDEDB),
  onErrorContainer: Color(0xFF5C0F0C),
  tertiary: Color(0xFF3F7A2A),
  markBg: Color(0xFFFDE39A),
  markFg: Color(0xFF4A3A06),
);

/// Syntax-highlight palette used when rendering a rule's Himark code. These are
/// theme-independent in the brief (fixed hex per token class); only the brace
/// colour tracks [HimarkTokens.onSurfaceVariant].
class Syntax {
  const Syntax._();
  static const Color identifier = Color(0xFF61AFEF); // @l, @d
  static const Color quantifier = Color(0xFFD19A66); // [1..]
  static const Color value = Color(0xFFE5C07B); // @, @d::0..255
  static const Color special = Color(0xFFC678DD); // #
  static const Color escape = Color(0xFFE06C75); // \n
}

/// Shared monospace text family. Uses the platform monospace with a small
/// fallback chain so the app needs no bundled font files.
const String kMonoFamily = 'monospace';
const List<String> kMonoFallback = <String>[
  'Menlo',
  'Courier New',
  'monospace',
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
