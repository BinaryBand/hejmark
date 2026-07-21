import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme/tokens.dart';

/// The desktop icon rail: a 76px column of Projects and Rules at the top and
/// Settings at the foot, pinned to the left of everything else.
///
/// Projects and Rules are not destinations — they toggle which sidebar the shell
/// holds open next to the editor, and pressing the open one closes it. Only
/// Settings navigates, which is why it sits below the divider.
class DeskRail extends StatelessWidget {
  const DeskRail({super.key});

  static const double width = 76;

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: t.surfaceContainer,
        border: Border(right: BorderSide(color: t.outlineVariant)),
      ),
      child: Column(
        children: [
          _RailButton(
            icon: Icons.folder_outlined,
            label: 'Projects',
            active: s.deskSidebarActive(DeskSidebar.projects),
            tokens: t,
            onTap: () => s.pressRail(DeskSidebar.projects),
          ),
          const SizedBox(height: 4),
          _RailButton(
            icon: Icons.checklist,
            label: 'Rules',
            active: s.deskSidebarActive(DeskSidebar.rules),
            tokens: t,
            onTap: () => s.pressRail(DeskSidebar.rules),
          ),
          const Spacer(),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: t.outlineVariant,
          ),
          _RailButton(
            icon: Icons.settings_outlined,
            label: 'Settings',
            active: s.nav == NavTab.settings,
            tokens: t,
            onTap: () => s.goTo(NavTab.settings),
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.tokens,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final HimarkTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? tokens.onPrimaryContainer : tokens.onSurfaceVariant;
    return Tooltip(
      message: label,
      child: Material(
        color: active ? tokens.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
            child: Column(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
