import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// The Settings screen: appearance (theme, density), editor (font size,
/// whitespace, tab size) and about (spec link, restore defaults, reset data).
///
/// The two destructive-ish actions at the foot are deliberately separate:
/// *Restore* returns the preferences on this screen to their shipped values and
/// leaves the projects alone; *Reset* is the one that clears data.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const int _minFontSize = 12;
  static const int _maxFontSize = 18;

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;

    return Container(
      color: t.surface,
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                      color: t.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _section(
                    t,
                    'Appearance',
                    'Theme and layout density for the whole app.',
                  ),
                  _card(t, [
                    _row(
                      t,
                      title: 'Theme',
                      subtitle: 'Applies across the whole app',
                      trailing: Segmented<ThemeChoice>(
                        tokens: t,
                        value: s.theme,
                        onChanged: s.setTheme,
                        options: const [
                          (ThemeChoice.dark, 'Dark'),
                          (ThemeChoice.light, 'Light'),
                          (ThemeChoice.system, 'System'),
                        ],
                      ),
                    ),
                    _divider(t),
                    _row(
                      t,
                      title: 'Density',
                      subtitle: 'Row height and tap target size',
                      trailing: Segmented<Density>(
                        tokens: t,
                        value: s.density,
                        onChanged: s.setDensity,
                        options: const [
                          (Density.compact, 'Compact'),
                          (Density.comfortable, 'Comfortable'),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 22),

                  _section(
                    t,
                    'Editor',
                    'How test strings are displayed and edited.',
                  ),
                  _card(t, [
                    _row(t, title: 'Font size', trailing: _fontStepper(s, t)),
                    _divider(t),
                    _row(
                      t,
                      title: 'Show whitespace glyphs',
                      subtitle: 'Reveal dots and arrows for spaces and tabs',
                      trailing: Switch(
                        value: s.showWhitespace,
                        activeThumbColor: t.onPrimary,
                        activeTrackColor: t.primary,
                        inactiveTrackColor: t.surfaceContainerHigh,
                        onChanged: (_) => s.toggleWhitespace(),
                      ),
                    ),
                    _divider(t),
                    _row(
                      t,
                      title: 'Tab size',
                      trailing: Segmented<int>(
                        tokens: t,
                        value: s.tabSize,
                        onChanged: s.setTabSize,
                        options: const [(2, '2'), (4, '4'), (8, '8')],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 22),

                  _section(
                    t,
                    'About',
                    'Reference material and data management.',
                  ),
                  _card(t, [
                    InkWell(
                      onTap: () =>
                          s.showSnack('Opens https://example.com/himark-spec'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'View the Himark language spec',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: t.primary,
                                ),
                              ),
                            ),
                            Icon(Icons.north_east, size: 14, color: t.primary),
                          ],
                        ),
                      ),
                    ),
                    _divider(t),
                    _actionRow(
                      t,
                      title: 'Restore default settings',
                      subtitle: 'Reset theme, density, and editor options',
                      label: 'Restore',
                      onPressed: s.askRestoreDefaults,
                      color: t.onSurface,
                      borderColor: t.outline,
                    ),
                    _divider(t),
                    _actionRow(
                      t,
                      title: 'Reset app data',
                      subtitle: 'Clears saved projects and test strings',
                      label: 'Reset',
                      onPressed: s.askReset,
                      color: t.error,
                      borderColor: t.error,
                      titleColor: t.error,
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// An uppercase section label with the one-line blurb the brief pairs it with.
  Widget _section(HimarkTokens t, String title, String blurb) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(title, tokens: t),
          const SizedBox(height: 3),
          Text(
            blurb,
            style: TextStyle(
              fontSize: 12.5,
              color: t.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fontStepper(AppState s, HimarkTokens t) {
    Widget button(IconData icon, String tooltip, bool enabled, int delta) {
      return Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Material(
              color: t.surfaceContainerHigh,
              shape: CircleBorder(side: BorderSide(color: t.outlineVariant)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled
                    ? () => s.setFontSize(s.editorFontSize + delta)
                    : null,
                child: Icon(icon, size: 16, color: t.onSurface),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.remove, 'Decrease', s.editorFontSize > _minFontSize, -1),
        const SizedBox(width: 12),
        SizedBox(
          width: 52,
          child: Text(
            '${s.editorFontSize}px',
            textAlign: TextAlign.center,
            style: mono(
              fontSize: 15,
              color: t.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        button(Icons.add, 'Increase', s.editorFontSize < _maxFontSize, 1),
      ],
    );
  }

  Widget _card(HimarkTokens t, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      // Stretch, not the default centre: a row that shrink-wraps its width —
      // the foot's `Wrap` does — would otherwise be centred as a block, so its
      // title sat inset from the card edge and its button inset from the other,
      // reading as a cramped pair rather than a title opposite its action.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _divider(HimarkTokens t) => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    color: t.outlineVariant,
  );

  Widget _row(
    HimarkTokens t, {
    required String title,
    String? subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: t.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: t.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          trailing,
        ],
      ),
    );
  }

  /// A title/blurb pair with an outlined button on the right, wrapping onto a
  /// second line where the pane is narrow.
  Widget _actionRow(
    HimarkTokens t, {
    required String title,
    required String subtitle,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    required Color borderColor,
    Color? titleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: titleColor ?? t.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: t.onSurfaceVariant),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: borderColor),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
