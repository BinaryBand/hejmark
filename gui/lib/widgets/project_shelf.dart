import 'package:flutter/material.dart';

import '../models/project.dart';
import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'rename_field.dart';

/// The sliding project shelf: a scrim plus a 250px left panel listing projects,
/// with select / rename / more-menu per row and a "New project" action.
class ProjectShelf extends StatelessWidget {
  const ProjectShelf({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;

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
              left: (v - 1) * 250,
              width: 250,
              child: child!,
            ),
          ],
        );
      },
      child: _panel(s, t),
    );
  }

  Widget _panel(AppState s, HimarkTokens t) {
    return Material(
      color: t.surfaceContainerLow,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: t.outlineVariant)),
        ),
        child: SafeArea(
          right: false,
          child: Column(
            children: [
              _panelHeader(s, t),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  children: [
                    for (final p in s.projectsInOrder) _projectRow(s, t, p),
                  ],
                ),
              ),
              _panelFooter(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelHeader(AppState s, HimarkTokens t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'PROJECTS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: t.onSurfaceVariant,
              ),
            ),
          ),
          CircleIconButton(
            icon: Icons.add,
            iconSize: 14,
            size: 32,
            tooltip: 'New project',
            color: t.onSurfaceVariant,
            onTap: s.addNewProject,
          ),
        ],
      ),
    );
  }

  Widget _projectRow(AppState s, HimarkTokens t, Project p) {
    final isCurrent = s.currentProject == p.id;
    if (s.isEditing(MenuScope.project, p.id)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
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
                      ),
                      if (p.dirty)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: t.tertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          CircleIconButton(
            icon: Icons.more_vert,
            iconSize: 16,
            size: 32,
            tooltip: 'More',
            color: t.onSurfaceVariant,
            onTap: () => s.openMenu(MenuScope.project, p.id, p.name),
          ),
        ],
      ),
    );
  }

  Widget _panelFooter(HimarkTokens t) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.save_outlined, size: 13, color: t.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Changes save automatically',
              style: TextStyle(fontSize: 11.5, color: t.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
