import 'package:flutter/material.dart';

import '../models/project.dart';
import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'rename_field.dart';

/// The project list: a scrim-backed drawer that slides in on mobile, and a
/// pinned column the desktop rail opens and closes.
///
/// Both wrap the same [ProjectShelfPanel]; only the width and whether a scrim
/// sits behind it differ.
class ProjectShelf extends StatelessWidget {
  const ProjectShelf({super.key});

  static const double mobileWidth = 250;
  static const double desktopWidth = 300;

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, v, child) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: s.toggleShelf,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4 * v),
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: (v - 1) * mobileWidth,
              width: mobileWidth,
              child: child!,
            ),
          ],
        );
      },
      child: const SafeArea(right: false, child: ProjectShelfPanel()),
    );
  }
}

/// The panel itself: a header carrying the sort controls and the new-project
/// action, then one row per project.
class ProjectShelfPanel extends StatelessWidget {
  const ProjectShelfPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;
    final projects = s.projectsSorted;

    return Material(
      color: t.surfaceContainerLow,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: t.outlineVariant)),
        ),
        child: Column(
          children: [
            _header(s, t),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                children: [
                  for (final p in projects) ...[
                    _projectRow(s, t, p),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      color: t.outlineVariant,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppState s, HimarkTokens t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(child: SectionLabel('Projects', tokens: t)),
          CircleIconButton(
            icon: _sortTargetIcon(s.projectSort),
            iconSize: 14,
            size: 28,
            tooltip: _sortTargetTooltip(s.projectSort),
            color: t.onSurfaceVariant,
            onTap: s.cycleSortTarget,
          ),
          CircleIconButton(
            icon: s.sortDir == SortDir.asc
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            iconSize: 14,
            size: 28,
            tooltip: s.sortDir == SortDir.asc ? 'Ascending' : 'Descending',
            color: t.onSurfaceVariant,
            onTap: s.toggleSortDir,
          ),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: t.outlineVariant,
          ),
          CircleIconButton(
            icon: Icons.add,
            iconSize: 13,
            size: 28,
            tooltip: 'New project',
            color: t.onSurfaceVariant,
            onTap: s.addNewProject,
          ),
        ],
      ),
    );
  }

  static IconData _sortTargetIcon(ProjectSort sort) {
    switch (sort) {
      case ProjectSort.manual:
        return Icons.format_list_bulleted;
      case ProjectSort.name:
        return Icons.sort_by_alpha;
      case ProjectSort.date:
        return Icons.calendar_today_outlined;
    }
  }

  /// Names the current order and what the next press gives, so the cycle is
  /// discoverable from one hover.
  static String _sortTargetTooltip(ProjectSort sort) {
    switch (sort) {
      case ProjectSort.manual:
        return 'Custom order (click to sort by name)';
      case ProjectSort.name:
        return 'Sorted by name (click for date)';
      case ProjectSort.date:
        return 'Sorted by date (click for custom)';
    }
  }

  Widget _projectRow(AppState s, HimarkTokens t, Project p) {
    final isCurrent = s.currentProject == p.id;
    if (s.isEditing(MenuScope.project, p.id)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.primary, width: 2),
          ),
          child: RenameField(
            initial: p.name,
            color: t.onSurface,
            onChanged: s.setEditingValue,
            onSubmit: s.commitRename,
            onCancel: s.cancelRename,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: isCurrent ? t.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => s.selectProject(p.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isCurrent
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isCurrent
                                    ? t.onPrimaryContainer
                                    : t.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              formatEdited(p.updatedAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: t.onSurfaceVariant.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (p.dirty) ...[
                        const SizedBox(width: 7),
                        Tooltip(
                          message: 'Unsaved',
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: t.tertiary,
                              shape: BoxShape.circle,
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
          const SizedBox(width: 4),
          CircleIconButton(
            icon: Icons.more_vert,
            iconSize: 15,
            size: 30,
            tooltip: 'More',
            color: t.onSurfaceVariant,
            onTap: () => s.openMenu(MenuScope.project, p.id, p.name),
          ),
        ],
      ),
    );
  }
}
