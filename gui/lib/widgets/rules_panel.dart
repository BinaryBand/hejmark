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
/// row to toggle it, drag the handle to reorder, swipe it left to delete, and
/// press the pencil to rewrite its source in place.
///
/// Editing is a *separate* affordance from the tap, not a replacement for it:
/// the code block is the row's whole body, so making it the text field's tap
/// target would leave no way to toggle a rule off.
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
        final editing = s.editingRule == rule.id;
        return Column(
          key: ValueKey(rule.id),
          mainAxisSize: MainAxisSize.min,
          children: [
            // A row being edited is not swipeable: a horizontal drag inside the
            // field is a text selection, and losing the rule to it would be a
            // surprise no `Undo` snack makes up for.
            if (editing)
              _row(s, t, project, rule, enabled, i, rowPad, editing: true)
            else
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
    EdgeInsets rowPad, {
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
            const SizedBox(width: 4),
            CircleIconButton(
              icon: editing ? Icons.check : Icons.edit_outlined,
              iconSize: 15,
              size: 32,
              tooltip: editing ? 'Done editing' : 'Edit rule',
              color: editing ? t.primary : t.onSurfaceVariant,
              onTap: editing ? s.endRuleEdit : () => s.startRuleEdit(rule.id),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: t.surfaceContainerLow,
      // While the editor is open the row must not swallow taps into a toggle —
      // reaching past the field to place a cursor would flip the rule instead.
      child: editing
          ? body
          : InkWell(onTap: () => s.toggleRule(rule.id), child: body),
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
