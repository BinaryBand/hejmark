import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme/tokens.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/overlays.dart';
import '../widgets/project_shelf.dart';
import '../widgets/top_bar.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';
import 'test_screen.dart';

/// Width at or above which the app switches from the mobile phone frame to the
/// desktop multi-pane layout.
const double kDesktopBreakpoint = 840;

/// The app shell. Adaptive: below [kDesktopBreakpoint] it renders the brief's
/// centred phone frame with a bottom nav; at or above it renders a navigation
/// rail with a multi-pane body (Rules alongside Test). Overlays (shelf, context
/// menu, confirm dialog, snackbar) are shared across both.
class HomeScaffold extends StatelessWidget {
  const HomeScaffold({super.key});

  Widget _screen(NavTab nav) {
    switch (nav) {
      case NavTab.rules:
        return const RulesScreen();
      case NavTab.test:
        return const TestScreen();
      case NavTab.settings:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final t = scope.tokens;

    return Scaffold(
      backgroundColor: t.surfaceDim,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= kDesktopBreakpoint;
          return wide ? _desktop(scope.state, t) : _mobile(scope.state, t);
        },
      ),
    );
  }

  /// Overlays layered above the content in both layouts.
  List<Widget> _overlays(AppState s) => [
    if (s.snack != null) const SnackBarOverlay(),
    if (s.shelfOpen) const ProjectShelf(),
    if (s.menu != null) const ActionSheet(),
    if (s.confirm != null) const ConfirmDialog(),
  ];

  // ---------------------------------------------------------------------------
  // Mobile: centred phone frame + bottom nav
  // ---------------------------------------------------------------------------

  Widget _mobile(AppState s, HimarkTokens t) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 40,
              ),
            ],
          ),
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
                ..._overlays(s),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop: navigation rail + multi-pane body
  // ---------------------------------------------------------------------------

  Widget _desktop(AppState s, HimarkTokens t) {
    return ColoredBox(
      color: t.surface,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                const TopBar(),
                Expanded(
                  child: Row(
                    children: [
                      _rail(s, t),
                      VerticalDivider(width: 1, color: t.outlineVariant),
                      Expanded(child: _desktopContent(s, t)),
                    ],
                  ),
                ),
              ],
            ),
            ..._overlays(s),
          ],
        ),
      ),
    );
  }

  Widget _rail(AppState s, HimarkTokens t) {
    NavigationRailDestination dest(IconData icon, String label) =>
        NavigationRailDestination(icon: Icon(icon), label: Text(label));

    return NavigationRail(
      backgroundColor: t.surfaceContainer,
      selectedIndex: s.nav.index,
      onDestinationSelected: (i) => s.goTo(NavTab.values[i]),
      labelType: NavigationRailLabelType.all,
      indicatorColor: t.primaryContainer,
      selectedIconTheme: IconThemeData(color: t.onPrimaryContainer),
      unselectedIconTheme: IconThemeData(color: t.onSurfaceVariant),
      selectedLabelTextStyle: TextStyle(
        color: t.primary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: t.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      destinations: [
        dest(Icons.checklist, 'Rules'),
        dest(Icons.terminal, 'Test'),
        dest(Icons.settings_outlined, 'Settings'),
      ],
    );
  }

  /// The primary content for the current destination. Test pairs the Rules list
  /// with the editor; the rest are single, comfortably-capped panes.
  Widget _desktopContent(AppState s, HimarkTokens t) {
    switch (s.nav) {
      case NavTab.test:
        return Row(
          children: [
            SizedBox(width: 360, child: _screen(NavTab.rules)),
            VerticalDivider(width: 1, color: t.outlineVariant),
            Expanded(child: _screen(NavTab.test)),
          ],
        );
      case NavTab.rules:
        return _capped(maxWidth: 640, child: _screen(NavTab.rules));
      case NavTab.settings:
        return _capped(maxWidth: 720, child: _screen(NavTab.settings));
    }
  }

  Widget _capped({required double maxWidth, required Widget child}) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
