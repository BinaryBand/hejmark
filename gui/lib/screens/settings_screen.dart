import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// The Settings screen: appearance (theme, density), editor (font size,
/// whitespace, tab size) and about (spec link, reset).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;

    return Container(
      color: t.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel('Appearance', tokens: t),
            const SizedBox(height: 10),
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

            SectionLabel('Editor', tokens: t),
            const SizedBox(height: 10),
            _card(t, [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Font size',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: t.onSurface,
                          ),
                        ),
                        Text(
                          '${s.editorFontSize}px',
                          style: mono(
                            fontSize: 12.5,
                            color: t.onSurfaceVariant,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: t.primary,
                        inactiveTrackColor: t.surfaceContainerHigh,
                        thumbColor: t.primary,
                        overlayColor: t.primary.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        min: 12,
                        max: 18,
                        divisions: 6,
                        value: s.editorFontSize.toDouble(),
                        onChanged: (v) => s.setFontSize(v.round()),
                      ),
                    ),
                  ],
                ),
              ),
              _divider(t),
              _row(
                t,
                title: 'Show whitespace glyphs',
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

            SectionLabel('About', tokens: t),
            const SizedBox(height: 10),
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
                          style: TextStyle(fontSize: 13.5, color: t.primary),
                        ),
                      ),
                      Icon(Icons.north_east, size: 14, color: t.primary),
                    ],
                  ),
                ),
              ),
              _divider(t),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reset app data',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: t.error,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Clears saved projects and test strings',
                            style: TextStyle(
                              fontSize: 12,
                              color: t.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: s.askReset,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.error,
                        side: BorderSide(color: t.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _card(HimarkTokens t, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
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
}
