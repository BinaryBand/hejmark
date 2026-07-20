import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/scope.dart';

/// The bottom navigation bar: Rules · Test · Settings.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;

    Widget item(NavTab tab, IconData icon, String label) {
      final selected = s.nav == tab;
      final color = selected ? t.primary : t.onSurfaceVariant;
      return Expanded(
        child: InkWell(
          onTap: () => s.goTo(tab),
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: t.surfaceContainer,
        border: Border(top: BorderSide(color: t.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            item(NavTab.rules, Icons.checklist, 'Rules'),
            item(NavTab.test, Icons.terminal, 'Test'),
            item(NavTab.settings, Icons.settings_outlined, 'Settings'),
          ],
        ),
      ),
    );
  }
}
