import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/scope.dart';
import 'common.dart';

/// The 56px top app bar. On Rules/Test it shows the shelf toggle, the
/// project name and the save status; on Test it also carries the view toggle
/// (when the tab strip is collapsed) and the collapse-tabs chevron. On Settings
/// it shows a plain title.
class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;
    final isSettings = s.nav == NavTab.settings;
    final isTest = s.nav == NavTab.test;

    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 10, right: 8),
      decoration: BoxDecoration(
        color: t.surfaceContainer,
        border: Border(bottom: BorderSide(color: t.outlineVariant)),
      ),
      child: Row(
        children: [
          CircleIconButton(
            icon: Icons.menu,
            tooltip: 'Menu',
            color: t.onSurfaceVariant,
            onTap: s.toggleShelf,
          ),
          const SizedBox(width: 8),
          if (isSettings)
            Text(
              'Settings',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: t.onSurface,
              ),
            )
          else
            Expanded(
              child: Column(
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
              ),
            ),
          if (isSettings) const Spacer(),
          if (isTest) ...[
            if (!s.tabBarVisible)
              CircleIconButton(
                icon: s.editMode ? Icons.edit : Icons.visibility_outlined,
                tooltip: s.editMode ? 'View mode' : 'Edit mode',
                background: t.surfaceContainerHigh,
                color: s.editMode ? t.primary : t.onSurfaceVariant,
                onTap: s.toggleEditMode,
              ),
            const SizedBox(width: 4),
            CircleIconButton(
              icon: Icons.keyboard_arrow_down,
              tooltip: 'Collapse tabs',
              color: t.onSurfaceVariant,
              rotation: s.tabBarVisible ? 0 : 0.5,
              onTap: s.toggleTabBar,
            ),
          ],
        ],
      ),
    );
  }
}
