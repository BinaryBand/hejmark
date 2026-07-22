import 'package:flutter/material.dart';

import '../models/project.dart';
import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme/schemes.dart';
import '../theme/tokens.dart';

/// Bottom action sheet (context menu). A tab or project gets Rename / Duplicate
/// / Delete; a rule gets Edit pattern / Syntax reference / Duplicate / Enable /
/// Highlight colour / Delete, because it has no name to rename.
class ActionSheet extends StatelessWidget {
  const ActionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;
    final menu = s.menu;
    if (menu == null) return const SizedBox.shrink();

    Widget item(IconData icon, String label, Color color, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: s.closeMenu,
            child: Container(color: Colors.black.withValues(alpha: 0.45)),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _slideUp(
                  child: Material(
                    color: t.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                          child: Text(
                            menu.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: t.onSurfaceVariant,
                            ),
                          ),
                        ),
                        // A rule has no name to rename — its source is its
                        // identity — so its first item opens the editor, and it
                        // carries the two affordances the row has nowhere else
                        // to put: the syntax reference and the colour pin.
                        if (menu.scope == MenuScope.rule) ...[
                          item(
                            Icons.edit_outlined,
                            'Edit pattern',
                            t.onSurface,
                            () => s.startRuleEdit(menu.id),
                          ),
                          item(
                            Icons.menu_book_outlined,
                            'Syntax reference',
                            t.onSurface,
                            s.openCheat,
                          ),
                          item(
                            Icons.content_copy_outlined,
                            'Duplicate',
                            t.onSurface,
                            () => s.duplicate(menu.scope, menu.id),
                          ),
                          item(
                            Icons.power_settings_new,
                            (s.cur?.enabled[menu.id] ?? false)
                                ? 'Disable'
                                : 'Enable',
                            t.onSurface,
                            () {
                              s.toggleRule(menu.id);
                              s.closeMenu();
                            },
                          ),
                          item(
                            Icons.water_drop_outlined,
                            'Highlight colour',
                            t.onSurface,
                            () => s.openColorPick(menu.id),
                          ),
                        ] else ...[
                          item(
                            Icons.edit_outlined,
                            'Rename',
                            t.onSurface,
                            () => s.startRename(menu.scope, menu.id),
                          ),
                          item(
                            Icons.content_copy_outlined,
                            'Duplicate',
                            t.onSurface,
                            () => s.duplicate(menu.scope, menu.id),
                          ),
                        ],
                        item(
                          Icons.delete_outline,
                          'Delete',
                          t.error,
                          () => s.requestDelete(menu.scope, menu.id),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _slideUp({required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      builder: (context, v, c) =>
          Transform.translate(offset: Offset(0, v * 40), child: c),
      child: child,
    );
  }
}

/// The per-rule highlight swatch sheet: six colours and an AUTO that unpins.
///
/// A pin is the exception, not the rule — without one a rule wears the colour
/// its position in the project cycles onto, which is what keeps a fresh project
/// legible with no choices made. AUTO is therefore a first-class option here
/// rather than a reset buried elsewhere.
class ColorPickSheet extends StatelessWidget {
  const ColorPickSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;
    final ruleId = s.colorPick;
    if (ruleId == null) return const SizedBox.shrink();

    HighlightSwatch? pinned;
    for (final r in s.cur?.rules ?? const <Rule>[]) {
      if (r.id == ruleId) pinned = r.color;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: s.closeColorPick,
            child: Container(color: Colors.black.withValues(alpha: 0.45)),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Material(
                  color: t.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                        child: Text(
                          'HIGHLIGHT COLOUR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: t.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final swatch in HighlightSwatch.values)
                              _swatch(
                                s,
                                t,
                                ruleId,
                                swatch,
                                selected: pinned == swatch,
                                brightness: scope.brightness,
                              ),
                            _auto(s, t, ruleId, selected: pinned == null),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _swatch(
    AppState s,
    HimarkTokens t,
    String ruleId,
    HighlightSwatch swatch, {
    required bool selected,
    required Brightness brightness,
  }) {
    final colors = swatchColors(swatch, brightness);
    return Tooltip(
      message: swatch.name,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: Colors.transparent,
          shape: CircleBorder(
            side: BorderSide(
              color: selected ? t.onSurface : Colors.transparent,
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => s.setRuleColor(ruleId, swatch),
            child: Center(
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: colors.dot,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _auto(
    AppState s,
    HimarkTokens t,
    String ruleId, {
    required bool selected,
  }) {
    return Tooltip(
      message: 'Automatic (by position in the project)',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: Colors.transparent,
          shape: CircleBorder(
            side: BorderSide(color: selected ? t.onSurface : t.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => s.setRuleColor(ruleId, null),
            child: Center(
              child: Text(
                'AUTO',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: t.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered confirm dialog with a Cancel and a (possibly dangerous) action.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;
    final cf = s.confirm;
    if (cf == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: s.cancelConfirm,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: GestureDetector(
          onTap: () {},
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Material(
              color: t.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cf.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: t.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cf.detail,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: t.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: s.cancelConfirm,
                          style: TextButton.styleFrom(
                            foregroundColor: t.primary,
                            minimumSize: const Size(0, 44),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: s.runConfirm,
                          style: FilledButton.styleFrom(
                            backgroundColor: cf.danger ? t.error : t.primary,
                            foregroundColor: cf.danger
                                ? t.onError
                                : t.onPrimary,
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(21),
                            ),
                          ),
                          child: Text(cf.label),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating snackbar with an optional action (e.g. Undo).
class SnackBarOverlay extends StatelessWidget {
  const SnackBarOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;
    final snack = s.snack;
    if (snack == null) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      right: 12,
      bottom: 72,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: 0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              builder: (context, v, child) => Opacity(
                opacity: 1 - v,
                child: Transform.translate(
                  offset: Offset(0, v * 30),
                  child: child,
                ),
              ),
              child: Material(
                color: t.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          snack.message,
                          style: TextStyle(fontSize: 13, color: t.onSurface),
                        ),
                      ),
                      if (snack.onAction != null) ...[
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: snack.onAction,
                          style: TextButton.styleFrom(
                            foregroundColor: t.primary,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: Text(
                            snack.actionLabel ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
