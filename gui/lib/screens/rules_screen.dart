import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/rules.dart';
import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/rule_code.dart';

/// The Rules screen: an ordered, toggleable, reorderable list of pattern rules
/// with an "Add rule" action.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

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
                : _list(context, s, t, project!),
          ),
          _addButton(s, t),
        ],
      ),
    );
  }

  Widget _header(AppState s, HimarkTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel('Rules', tokens: tokens),
                const SizedBox(height: 2),
                Text(
                  s.currentProjectName,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: tokens.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: tokens.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${s.cur?.enabledCount ?? 0} active',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(
    BuildContext context,
    AppState s,
    HimarkTokens tokens,
    Project project,
  ) {
    final rowPad = s.density == Density.compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 10);

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      buildDefaultDragHandles: false,
      onReorderItem: s.reorderRule,
      proxyDecorator: (child, index, animation) => Material(
        color: tokens.surfaceContainerHigh,
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
            Opacity(
              opacity: enabled ? 1 : 0.5,
              child: Padding(
                padding: rowPad,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: SizedBox(
                          width: 32,
                          height: 40,
                          child: Icon(
                            Icons.drag_indicator,
                            size: 18,
                            color: tokens.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Checkbox(
                        value: enabled,
                        activeColor: tokens.primary,
                        onChanged: (_) => s.toggleRule(rule.id),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ruleLabel(rule.kind),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: tokens.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          RuleCode(
                            spans: ruleSpans(
                              rule.kind,
                              tokens.onSurfaceVariant,
                            ),
                            fontSize: s.editorFontSize.toDouble(),
                            tokens: tokens,
                          ),
                        ],
                      ),
                    ),
                    CircleIconButton(
                      icon: Icons.close,
                      iconSize: 15,
                      color: tokens.onSurfaceVariant,
                      onTap: () => s.removeRule(rule.id),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: tokens.outlineVariant,
            ),
          ],
        );
      },
    );
  }

  Widget _addButton(AppState s, HimarkTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: s.addRule,
            style: FilledButton.styleFrom(
              backgroundColor: tokens.primaryContainer,
              foregroundColor: tokens.onPrimaryContainer,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text(
              'Add rule',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
