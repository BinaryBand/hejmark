import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/scope.dart';
import 'common.dart';

/// The 56px app bar over the main column.
///
/// It names the current project and its save state, and on the Test destination
/// carries the three controls over the editor: the find/run verb, the
/// edit/view toggle and the collapse-tabs chevron. The shelf button is a mobile
/// affordance only — on desktop the rail already owns that job, so [isDesktop]
/// drops it.
class TopBar extends StatelessWidget {
  const TopBar({required this.isDesktop, super.key});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;
    final nav = s.navFor(wide: isDesktop);
    final isSettings = nav == NavTab.settings;

    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 10, right: 8),
      decoration: BoxDecoration(
        color: t.surfaceContainer,
        border: Border(bottom: BorderSide(color: t.outlineVariant)),
      ),
      child: Row(
        children: [
          // Exactly one child claims the free space, so the controls below sit
          // hard against the right edge. A `Flexible` title beside a `Spacer`
          // would not: both carry flex 1, so the row would split the free space
          // between them and the loose title would hand its half back as a gap
          // after the last button.
          if (isSettings)
            Expanded(
              child: Text(
                'Preferences',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: t.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            if (!isDesktop) ...[
              CircleIconButton(
                icon: Icons.menu,
                tooltip: 'Menu',
                color: t.onSurfaceVariant,
                onTap: s.toggleShelf,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: _projectTitle(s, scope)),
          ],
          // The cheat sheet is reachable from every workspace destination, not
          // only Test — a rule is written on the Rules screen, which is exactly
          // where the syntax reference is wanted.
          if (!isSettings) ...[
            CircleIconButton(
              icon: Icons.menu_book_outlined,
              tooltip: 'Himark syntax cheat sheet',
              color: t.onSurfaceVariant,
              onTap: s.openCheat,
            ),
            const SizedBox(width: 4),
          ],
          if (nav == NavTab.test) ...[
            CircleIconButton(
              icon: Icons.play_arrow_outlined,
              iconSize: 16,
              tooltip: s.runMode ? 'Find matches' : 'Run as script',
              background: s.runMode
                  ? t.primaryContainer
                  : t.surfaceContainerHigh,
              color: s.runMode ? t.onPrimaryContainer : t.onSurfaceVariant,
              onTap: s.toggleRunMode,
            ),
            const SizedBox(width: 4),
            CircleIconButton(
              icon: s.editMode ? Icons.edit : Icons.visibility_outlined,
              iconSize: 16,
              tooltip: s.editMode ? 'View mode' : 'Edit mode',
              background: s.editMode
                  ? t.primaryContainer
                  : t.surfaceContainerHigh,
              color: s.editMode ? t.onPrimaryContainer : t.onSurfaceVariant,
              onTap: s.toggleEditMode,
            ),
            const SizedBox(width: 4),
            CircleIconButton(
              icon: Icons.keyboard_arrow_down,
              iconSize: 16,
              tooltip: s.tabBarVisible ? 'Collapse tabs' : 'Show tabs',
              color: t.onSurfaceVariant,
              rotation: s.tabBarVisible ? 0 : 0.5,
              onTap: s.toggleTabBar,
            ),
          ],
        ],
      ),
    );
  }

  Widget _projectTitle(AppState s, HimarkScope scope) {
    final t = scope.tokens;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.currentProjectName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: t.onSurface,
          ),
        ),
        const SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (s.isSaving) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: t.tertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              s.saveText,
              style: TextStyle(
                fontSize: 11,
                color: s.isSaving ? t.tertiary : t.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
