import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/rules.dart';
import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'rule_code.dart';

/// The rules list, shared by the desktop sidebar and the mobile Rules screen.
///
/// A row is its own Himark source and nothing else — the brief drops the prose
/// label, so the code *is* the identity. Reading a row: the dot at its top-right
/// is filled in the rule's colour when the rule is on and a hollow ring when it
/// is off, and that colour is the one its hits wear in the Test view. Tap the
/// row to toggle it, drag the handle to reorder, swipe it left to delete.
class RulesPanel extends StatelessWidget {
  const RulesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;
    final project = s.cur;
    final rules = project?.rules ?? const <Rule>[];

    return Container(
      color: t.surfaceContainerLow,
      child: Column(
        children: [
          _header(s, t),
          Container(height: 1, color: t.outlineVariant),
          Expanded(
            child: rules.isEmpty
                ? EmptyState(
                    tokens: t,
                    icon: Icons.checklist,
                    title: 'No rules yet',
                    hint:
                        'Add a pattern rule to start matching against your '
                        'test strings.',
                  )
                : _list(s, t, project!),
          ),
        ],
      ),
    );
  }

  Widget _header(AppState s, HimarkTokens t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(child: SectionLabel('Rules', tokens: t)),
          CircleIconButton(
            icon: Icons.add,
            iconSize: 13,
            size: 28,
            tooltip: 'Add rule',
            color: t.onSurfaceVariant,
            onTap: s.addRule,
          ),
        ],
      ),
    );
  }

  Widget _list(AppState s, HimarkTokens t, Project project) {
    final rowPad = s.density == Density.compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 10);

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      buildDefaultDragHandles: false,
      onReorderItem: s.reorderRule,
      proxyDecorator: (child, index, animation) => Material(
        color: t.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
      itemCount: project.rules.length,
      itemBuilder: (context, i) {
        final rule = project.rules[i];
        final enabled = project.enabled[rule.id] ?? false;
        return Column(
          key: ValueKey(rule.id),
          mainAxisSize: MainAxisSize.min,
          children: [
            Dismissible(
              key: ValueKey('dismiss-${rule.id}'),
              direction: DismissDirection.endToStart,
              dismissThresholds: const <DismissDirection, double>{
                DismissDirection.endToStart: 0.3,
              },
              background: _deleteReveal(t),
              onDismissed: (_) => s.removeRule(rule.id),
              child: _row(s, t, project, rule, enabled, i, rowPad),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: t.outlineVariant,
            ),
          ],
        );
      },
    );
  }

  /// What sits under a row while it is swiped aside.
  Widget _deleteReveal(HimarkTokens t) {
    return Container(
      color: t.errorContainer,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Icon(Icons.delete_outline, size: 18, color: t.onErrorContainer),
    );
  }

  Widget _row(
    AppState s,
    HimarkTokens t,
    Project project,
    Rule rule,
    bool enabled,
    int index,
    EdgeInsets rowPad,
  ) {
    return Material(
      color: t.surfaceContainerLow,
      child: InkWell(
        onTap: () => s.toggleRule(rule.id),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Padding(
            padding: rowPad,
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Tooltip(
                      message: 'Drag to reorder',
                      child: SizedBox(
                        width: 20,
                        height: 36,
                        child: Icon(
                          Icons.drag_indicator,
                          size: 16,
                          color: t.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      RuleCode(
                        spans: spansFor(rule.source, t.onSurfaceVariant),
                        fontSize: s.editorFontSize.toDouble(),
                        tokens: t,
                      ),
                      Positioned(
                        top: -3,
                        right: -3,
                        child: _statusDot(t, enabled, index),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Filled in the rule's own colour when it is on; a hollow ring in the muted
  /// outline when it is off.
  Widget _statusDot(HimarkTokens t, bool enabled, int index) {
    if (!enabled) {
      return Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: t.surfaceContainerLow,
          shape: BoxShape.circle,
          border: Border.all(color: t.outlineVariant, width: 1.5),
        ),
      );
    }
    // A 10px dot ringed by 2px of the row's own background, so it reads as
    // punched out of the code block rather than sitting on it.
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: t.surfaceContainerLow,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: t.ruleColorAt(index).dot,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
