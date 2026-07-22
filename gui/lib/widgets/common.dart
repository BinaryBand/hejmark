import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A circular, borderless icon button (the app-bar / toolbar affordance used
/// throughout the brief). [background] transparent by default.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.color,
    this.background = Colors.transparent,
    this.size = 40,
    this.iconSize = 18,
    this.tooltip,
    this.rotation = 0,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color background;
  final double size;
  final double iconSize;
  final String? tooltip;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: AnimatedRotation(
              turns: rotation,
              duration: const Duration(milliseconds: 180),
              child: Icon(icon, size: iconSize, color: color),
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// The pill-style segmented control used in Settings (theme, density, tab size).
class Segmented<T> extends StatelessWidget {
  const Segmented({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.tokens,
    super.key,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final HimarkTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (opt, label) in options)
            GestureDetector(
              onTap: () => onChanged(opt),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                constraints: const BoxConstraints(minHeight: 38),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: opt == value ? tokens.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: opt == value
                        ? tokens.onPrimary
                        : tokens.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The small uppercase section label ("APPEARANCE", "RULES", …).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {required this.tokens, super.key});
  final String text;
  final HimarkTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: tokens.primary,
      ),
    );
  }
}

/// A centered empty-state block: round icon, title, and a hint line.
///
/// [accent] paints the icon disc in the primary container rather than a plain
/// surface. The design uses it for the one empty state that has an action under
/// it — "No test string open" — and leaves the rules list's quiet, so the two do
/// not compete for the eye.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.hint,
    required this.tokens,
    this.action,
    this.accent = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String hint;
  final HimarkTokens tokens;
  final Widget? action;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent
                    ? tokens.primaryContainer
                    : tokens.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 26,
                color: accent
                    ? tokens.onPrimaryContainer
                    : tokens.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: tokens.onSurfaceVariant,
                ),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
