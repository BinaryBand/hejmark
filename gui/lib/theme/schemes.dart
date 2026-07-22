import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// The three colour schemes the design ships, each a whole surface palette
/// rather than an accent swap.
///
/// [ocean] is the original brief's blue-slate set; [airy] is the One UI–style
/// near-white/near-black pair the design makes the default; [joplin] is a
/// warmer slate with a periwinkle accent. Every scheme carries both a dark and
/// a light face, so the scheme and the theme are independent choices.
enum AppScheme { ocean, airy, joplin }

/// The six per-rule highlight overrides a rule can be pinned to, replacing the
/// colour its list position would otherwise give it.
enum HighlightSwatch { blue, green, purple, amber, red, teal }

/// The tokens for [scheme] at [brightness].
HimarkTokens tokensFor(AppScheme scheme, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  switch (scheme) {
    case AppScheme.ocean:
      return dark ? _oceanDark : _oceanLight;
    case AppScheme.airy:
      return dark ? _airyDark : _airyLight;
    case AppScheme.joplin:
      return dark ? _joplinDark : _joplinLight;
  }
}

/// The colours a rule pinned to [swatch] paints with at [brightness].
RuleColors swatchColors(HighlightSwatch swatch, Brightness brightness) =>
    (brightness == Brightness.dark ? _darkSwatches : _lightSwatches)[swatch]!;

const Map<HighlightSwatch, RuleColors> _darkSwatches =
    <HighlightSwatch, RuleColors>{
      HighlightSwatch.blue: RuleColors(
        dot: Color(0xFF5B9BF7),
        background: Color(0xFF1E3A5F),
        foreground: Color(0xFFBCD7FF),
      ),
      HighlightSwatch.green: RuleColors(
        dot: Color(0xFF7FC98F),
        background: Color(0xFF234029),
        foreground: Color(0xFFC8ECC8),
      ),
      HighlightSwatch.purple: RuleColors(
        dot: Color(0xFFB57FE0),
        background: Color(0xFF3A2A4A),
        foreground: Color(0xFFE4CDF4),
      ),
      HighlightSwatch.amber: RuleColors(
        dot: Color(0xFFD1B04F),
        background: Color(0xFF443D1B),
        foreground: Color(0xFFF4E4A1),
      ),
      HighlightSwatch.red: RuleColors(
        dot: Color(0xFFE8828A),
        background: Color(0xFF4D1A1F),
        foreground: Color(0xFFF8C6CA),
      ),
      HighlightSwatch.teal: RuleColors(
        dot: Color(0xFF4FC7C7),
        background: Color(0xFF123F3F),
        foreground: Color(0xFFBDF0F0),
      ),
    };

const Map<HighlightSwatch, RuleColors> _lightSwatches =
    <HighlightSwatch, RuleColors>{
      HighlightSwatch.blue: RuleColors(
        dot: Color(0xFF1B73E8),
        background: Color(0xFFE3EDFD),
        foreground: Color(0xFF0B3D91),
      ),
      HighlightSwatch.green: RuleColors(
        dot: Color(0xFF3F9D58),
        background: Color(0xFFE0F2E4),
        foreground: Color(0xFF14401F),
      ),
      HighlightSwatch.purple: RuleColors(
        dot: Color(0xFF9B51E0),
        background: Color(0xFFF0E6FB),
        foreground: Color(0xFF3F1A66),
      ),
      HighlightSwatch.amber: RuleColors(
        dot: Color(0xFFC77D1A),
        background: Color(0xFFFDF0CF),
        foreground: Color(0xFF5A3A06),
      ),
      HighlightSwatch.red: RuleColors(
        dot: Color(0xFFC4342F),
        background: Color(0xFFFBDEDB),
        foreground: Color(0xFF5C0F0C),
      ),
      HighlightSwatch.teal: RuleColors(
        dot: Color(0xFF0F8F8F),
        background: Color(0xFFD6F2F2),
        foreground: Color(0xFF0A3D3D),
      ),
    };

// The syntax palettes. Unlike the brief's fixed hexes these track the theme,
// because `airy`'s and `joplin`'s light faces are far brighter than the
// original's and the dark-tuned code colours washed out on them.
const SyntaxColors _darkSyntax = SyntaxColors(
  identifier: Color(0xFF61AFEF),
  quantifier: Color(0xFFD19A66),
  value: Color(0xFFE5C07B),
  special: Color(0xFFC678DD),
  escape: Color(0xFFE06C75),
);

const SyntaxColors _lightSyntax = SyntaxColors(
  identifier: Color(0xFF1A66C0),
  quantifier: Color(0xFFB5651D),
  value: Color(0xFF8A6D00),
  special: Color(0xFF8E3FB8),
  escape: Color(0xFFC4342F),
);

// --- ocean: the original brief -------------------------------------------

const List<RuleColors> _oceanDarkRules = <RuleColors>[
  RuleColors(
    dot: Color(0xFF5B9BF7),
    background: Color(0xFF1E3A5F),
    foreground: Color(0xFFBCD7FF),
  ),
  RuleColors(
    dot: Color(0xFF98C379),
    background: Color(0xFF2C4022),
    foreground: Color(0xFFD3ECBF),
  ),
  RuleColors(
    dot: Color(0xFFC678DD),
    background: Color(0xFF3D2A4A),
    foreground: Color(0xFFE9CDF4),
  ),
  RuleColors(
    dot: Color(0xFFD1B04F),
    background: Color(0xFF4A431B),
    foreground: Color(0xFFF4E4A1),
  ),
];

const List<RuleColors> _oceanLightRules = <RuleColors>[
  RuleColors(
    dot: Color(0xFF2F6FE0),
    background: Color(0xFFD9E6FD),
    foreground: Color(0xFF0D3A78),
  ),
  RuleColors(
    dot: Color(0xFF3F7A2A),
    background: Color(0xFFDDEFD1),
    foreground: Color(0xFF1E4210),
  ),
  RuleColors(
    dot: Color(0xFF8E3FB8),
    background: Color(0xFFEFDCF8),
    foreground: Color(0xFF48195F),
  ),
  RuleColors(
    dot: Color(0xFFB0821F),
    background: Color(0xFFFDE39A),
    foreground: Color(0xFF4A3A06),
  ),
];

const HimarkTokens _oceanDark = HimarkTokens(
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
  ruleColors: _oceanDarkRules,
  syntax: _darkSyntax,
);

const HimarkTokens _oceanLight = HimarkTokens(
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
  ruleColors: _oceanLightRules,
  syntax: _lightSyntax,
);

// --- airy: One UI–style, near-white surfaces and whisper-light dividers ----

const List<RuleColors> _airyDarkRules = <RuleColors>[
  RuleColors(
    dot: Color(0xFF5B9BF7),
    background: Color(0xFF1E3A5F),
    foreground: Color(0xFFBCD7FF),
  ),
  RuleColors(
    dot: Color(0xFF7FC98F),
    background: Color(0xFF234029),
    foreground: Color(0xFFC8ECC8),
  ),
  RuleColors(
    dot: Color(0xFFB57FE0),
    background: Color(0xFF3A2A4A),
    foreground: Color(0xFFE4CDF4),
  ),
  RuleColors(
    dot: Color(0xFFD1B04F),
    background: Color(0xFF443D1B),
    foreground: Color(0xFFF4E4A1),
  ),
];

const List<RuleColors> _airyLightRules = <RuleColors>[
  RuleColors(
    dot: Color(0xFF1B73E8),
    background: Color(0xFFE3EDFD),
    foreground: Color(0xFF0B3D91),
  ),
  RuleColors(
    dot: Color(0xFF3F9D58),
    background: Color(0xFFE0F2E4),
    foreground: Color(0xFF14401F),
  ),
  RuleColors(
    dot: Color(0xFF9B51E0),
    background: Color(0xFFF0E6FB),
    foreground: Color(0xFF3F1A66),
  ),
  RuleColors(
    dot: Color(0xFFC77D1A),
    background: Color(0xFFFDF0CF),
    foreground: Color(0xFF5A3A06),
  ),
];

const HimarkTokens _airyDark = HimarkTokens(
  surface: Color(0xFF17181A),
  surfaceDim: Color(0xFF0F0F11),
  surfaceBright: Color(0xFF222327),
  surfaceContainerLowest: Color(0xFF0D0D0F),
  surfaceContainerLow: Color(0xFF151618),
  surfaceContainer: Color(0xFF1B1C1F),
  surfaceContainerHigh: Color(0xFF222327),
  surfaceContainerHighest: Color(0xFF2A2B2F),
  onSurface: Color(0xFFE8E8EA),
  onSurfaceVariant: Color(0xFF9A9AA0),
  primary: Color(0xFF5B9BF7),
  onPrimary: Color(0xFF062544),
  primaryContainer: Color(0xFF1E3A5F),
  onPrimaryContainer: Color(0xFFBCD7FF),
  outline: Color(0xFF3A3B40),
  outlineVariant: Color(0xFF232428),
  error: Color(0xFFE8828A),
  onError: Color(0xFF4A0D12),
  errorContainer: Color(0xFF4D1A1F),
  onErrorContainer: Color(0xFFF8C6CA),
  tertiary: Color(0xFF7FC98F),
  ruleColors: _airyDarkRules,
  syntax: _darkSyntax,
);

const HimarkTokens _airyLight = HimarkTokens(
  surface: Color(0xFFFAFAFA),
  surfaceDim: Color(0xFFE6E6E8),
  surfaceBright: Color(0xFFFFFFFF),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF5F5F6),
  surfaceContainer: Color(0xFFF0F0F2),
  surfaceContainerHigh: Color(0xFFEAEAEC),
  surfaceContainerHighest: Color(0xFFE3E3E6),
  onSurface: Color(0xFF1A1A1C),
  onSurfaceVariant: Color(0xFF6E6E73),
  primary: Color(0xFF1B73E8),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFE3EDFD),
  onPrimaryContainer: Color(0xFF0B3D91),
  outline: Color(0xFFD4D4D8),
  outlineVariant: Color(0xFFEDEDF0),
  error: Color(0xFFC4342F),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFBDEDB),
  onErrorContainer: Color(0xFF5C0F0C),
  tertiary: Color(0xFF3F9D58),
  ruleColors: _airyLightRules,
  syntax: _lightSyntax,
);

// --- joplin: slate-gray editor surfaces, periwinkle accent ----------------

const List<RuleColors> _joplinDarkRules = <RuleColors>[
  RuleColors(
    dot: Color(0xFF61AFEF),
    background: Color(0xFF25406E),
    foreground: Color(0xFFC3D6F7),
  ),
  RuleColors(
    dot: Color(0xFF98C379),
    background: Color(0xFF2C4022),
    foreground: Color(0xFFD3ECBF),
  ),
  RuleColors(
    dot: Color(0xFFC678DD),
    background: Color(0xFF3D2A4A),
    foreground: Color(0xFFE9CDF4),
  ),
  RuleColors(
    dot: Color(0xFFE5C07B),
    background: Color(0xFF4A3D1B),
    foreground: Color(0xFFF4E4A1),
  ),
];

const List<RuleColors> _joplinLightRules = <RuleColors>[
  RuleColors(
    dot: Color(0xFF2B6BD6),
    background: Color(0xFFD6E2FA),
    foreground: Color(0xFF123A78),
  ),
  RuleColors(
    dot: Color(0xFF4A7A2A),
    background: Color(0xFFDCECC8),
    foreground: Color(0xFF233D10),
  ),
  RuleColors(
    dot: Color(0xFF8E3FB8),
    background: Color(0xFFEFDCF8),
    foreground: Color(0xFF48195F),
  ),
  RuleColors(
    dot: Color(0xFFB0821F),
    background: Color(0xFFFDF0A8),
    foreground: Color(0xFF4A3A06),
  ),
];

const HimarkTokens _joplinDark = HimarkTokens(
  surface: Color(0xFF1C2026),
  surfaceDim: Color(0xFF14171C),
  surfaceBright: Color(0xFF262B33),
  surfaceContainerLowest: Color(0xFF101216),
  surfaceContainerLow: Color(0xFF181B21),
  surfaceContainer: Color(0xFF1F232A),
  surfaceContainerHigh: Color(0xFF262B33),
  surfaceContainerHighest: Color(0xFF2F353E),
  onSurface: Color(0xFFD6DBE2),
  onSurfaceVariant: Color(0xFF8A929D),
  primary: Color(0xFF3B6FD6),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFF25406E),
  onPrimaryContainer: Color(0xFFC3D6F7),
  outline: Color(0xFF3A414C),
  outlineVariant: Color(0xFF262B33),
  error: Color(0xFFE8828A),
  onError: Color(0xFF4A0D12),
  errorContainer: Color(0xFF4D1A1F),
  onErrorContainer: Color(0xFFF8C6CA),
  tertiary: Color(0xFF98C379),
  ruleColors: _joplinDarkRules,
  syntax: _darkSyntax,
);

const HimarkTokens _joplinLight = HimarkTokens(
  surface: Color(0xFFFFFFFF),
  surfaceDim: Color(0xFFD0D4DA),
  surfaceBright: Color(0xFFFFFFFF),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF4F5F7),
  surfaceContainer: Color(0xFFECEEF1),
  surfaceContainerHigh: Color(0xFFE2E5E9),
  surfaceContainerHighest: Color(0xFFD6DAE0),
  onSurface: Color(0xFF22272E),
  onSurfaceVariant: Color(0xFF5A616B),
  primary: Color(0xFF2B6BD6),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFD6E2FA),
  onPrimaryContainer: Color(0xFF123A78),
  outline: Color(0xFFC2C7CF),
  outlineVariant: Color(0xFFE2E5E9),
  error: Color(0xFFC4342F),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFBDEDB),
  onErrorContainer: Color(0xFF5C0F0C),
  tertiary: Color(0xFF4A7A2A),
  ruleColors: _joplinLightRules,
  syntax: _lightSyntax,
);
