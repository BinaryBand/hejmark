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
/// is off, and that colour is the one its hits wear in the Test view.
///
/// Tap the row to edit its source in place, swipe it right to switch it on or
/// off, swipe it left to delete it, and drag the handle to reorder. Editing is
/// the tap because it is the frequent act; toggling has the whole row's width of
/// gesture to itself, and both stay in the overflow menu for anyone who would
/// rather not swipe.
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
                : _list(scope, s, t, project!),
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

  Widget _list(HimarkScope scope, AppState s, HimarkTokens t, Project project) {
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
        final editing = s.editingRule == rule.id;
        final dot = scope.colorsFor(rule, i).dot;
        return Column(
          key: ValueKey(rule.id),
          mainAxisSize: MainAxisSize.min,
          children: [
            // A row being edited is not swipeable: a horizontal drag inside the
            // field is a text selection, and losing the rule to it would be a
            // surprise no `Undo` snack makes up for.
            if (editing)
              _row(s, t, rule, enabled, i, rowPad, dot, editing: true)
            else
              Dismissible(
                key: ValueKey('dismiss-${rule.id}'),
                direction: DismissDirection.horizontal,
                dismissThresholds: const <DismissDirection, double>{
                  DismissDirection.startToEnd: 0.3,
                  DismissDirection.endToStart: 0.3,
                },
                background: _toggleReveal(t, enabled),
                secondaryBackground: _deleteReveal(t),
                // Only the leftward swipe really dismisses. A rightward one
                // toggles and answers false, so the row springs back to a list
                // it never left — the toggle is a gesture, not a removal.
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    s.toggleRule(rule.id);
                    return false;
                  }
                  return true;
                },
                onDismissed: (_) => s.removeRule(rule.id),
                child: _row(s, t, rule, enabled, i, rowPad, dot),
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

  /// What sits under a row while it is swiped rightward: the switch it is about
  /// to throw, named by the state the rule is *in* now.
  Widget _toggleReveal(HimarkTokens t, bool enabled) {
    return Container(
      color: t.primaryContainer,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.power_settings_new, size: 18, color: t.onPrimaryContainer),
          const SizedBox(width: 8),
          Text(
            enabled ? 'Disable' : 'Enable',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  /// What sits under a row while it is swiped leftward.
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
    Rule rule,
    bool enabled,
    int index,
    EdgeInsets rowPad,
    Color dot, {
    bool editing = false,
  }) {
    // An open editor stays fully lit whatever the rule's on/off state: you are
    // reading what you are typing, not what the engine is running.
    final body = Opacity(
      opacity: enabled || editing ? 1 : 0.5,
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
                  if (editing)
                    RuleField(
                      // Keyed on the rule so switching which row is open
                      // rebuilds the controller rather than reusing the text.
                      key: ValueKey('edit-${rule.id}'),
                      initial: rule.source,
                      fontSize: s.editorFontSize.toDouble(),
                      tokens: t,
                      onChanged: (value) => s.setRuleSource(rule.id, value),
                      onDone: s.endRuleEdit,
                    )
                  else
                    RuleCode(
                      spans: spansFor(
                        rule.source,
                        t.onSurfaceVariant,
                        t.syntax,
                      ),
                      fontSize: s.editorFontSize.toDouble(),
                      tokens: t,
                    ),
                  Positioned(
                    top: -3,
                    right: -3,
                    child: _statusDot(t, enabled, dot),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            if (editing)
              CircleIconButton(
                icon: Icons.check,
                iconSize: 15,
                size: 44,
                tooltip: 'Done editing',
                color: t.primary,
                onTap: s.endRuleEdit,
              )
            else
              CircleIconButton(
                icon: Icons.more_vert,
                iconSize: 15,
                size: 44,
                tooltip: 'More',
                color: t.onSurfaceVariant,
                onTap: () => s.openMenu(MenuScope.rule, rule.id, 'Rule'),
              ),
          ],
        ),
      ),
    );

    return Material(
      color: t.surfaceContainerLow,
      // An open editor is already the tap's destination, so the row must not sit
      // a second gesture over the field it opened.
      child: editing
          ? body
          : InkWell(onTap: () => s.startRuleEdit(rule.id), child: body),
    );
  }

  /// Filled in the rule's own colour when it is on; a hollow ring in the muted
  /// outline when it is off.
  Widget _statusDot(HimarkTokens t, bool enabled, Color dot) {
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
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
