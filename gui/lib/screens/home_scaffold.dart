import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/scope.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/overlays.dart';
import '../widgets/project_shelf.dart';
import '../widgets/top_bar.dart';
import 'expand_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';
import 'test_screen.dart';

/// The phone frame: top bar, the active screen, the bottom nav, and every
/// transient overlay (shelf, context menu, confirm dialog, snackbar). Centred
/// and capped at 560px so it keeps the mockup's proportions on wide screens.
class HomeScaffold extends StatelessWidget {
  const HomeScaffold({super.key});

  Widget _screen(NavTab nav) {
    switch (nav) {
      case NavTab.rules:
        return const RulesScreen();
      case NavTab.test:
        return const TestScreen();
      case NavTab.expand:
        return const ExpandScreen();
      case NavTab.settings:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;

    return Scaffold(
      backgroundColor: t.surfaceDim,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SizedBox.expand(
            child: ColoredBox(
              color: t.surface,
              child: SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        const TopBar(),
                        Expanded(child: _screen(s.nav)),
                        const BottomNav(),
                      ],
                    ),
                    if (s.snack != null) const SnackBarOverlay(),
                    if (s.shelfOpen) const ProjectShelf(),
                    if (s.menu != null) const ActionSheet(),
                    if (s.confirm != null) const ConfirmDialog(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
