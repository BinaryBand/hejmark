import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme/tokens.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/overlays.dart';
import '../widgets/project_shelf.dart';
import '../widgets/rail.dart';
import '../widgets/rules_panel.dart';
import '../widgets/top_bar.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';
import 'test_screen.dart';

/// Width at or above which the app switches from the mobile phone frame to the
/// desktop rail layout.
const double kDesktopBreakpoint = 840;

/// The app shell.
///
/// Below [kDesktopBreakpoint] it is the brief's centred phone frame: a bottom
/// nav across Rules / Test / Settings, with the project shelf sliding in over
/// the content. At or above it, an icon rail on the far left opens at most one
/// pinned sidebar — Projects or Rules — beside a main column that is always the
/// editor (or Settings). Overlays are shared by both.
class HomeScaffold extends StatelessWidget {
  const HomeScaffold({super.key});

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

  /// The main column's content, for whichever destination is really in force.
  Widget _screen(AppState s, {required bool wide}) {
    switch (s.navFor(wide: wide)) {
      case NavTab.rules:
        return const RulesScreen();
      case NavTab.test:
        return const TestScreen();
      case NavTab.settings:
        return const SettingsScreen();
    }
  }

  /// Overlays layered above the content. The shelf is on this list only where it
  /// is a drawer; on desktop it is a column in the layout instead.
  List<Widget> _overlays(AppState s, {required bool wide}) => [
    if (s.snack != null) const SnackBarOverlay(),
    if (!wide && s.shelfOpen) const ProjectShelf(),
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
                    const TopBar(isDesktop: false),
                    Expanded(child: _screen(s, wide: false)),
                    const BottomNav(),
                  ],
                ),
                ..._overlays(s, wide: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop: icon rail + at most one pinned sidebar + main column
  // ---------------------------------------------------------------------------

  Widget _desktop(AppState s, HimarkTokens t) {
    return ColoredBox(
      color: t.surface,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Row(
              children: [
                const DeskRail(),
                if (s.deskSidebarActive(DeskSidebar.projects))
                  const SizedBox(
                    width: ProjectShelf.desktopWidth,
                    child: ProjectShelfPanel(),
                  ),
                if (s.deskSidebarActive(DeskSidebar.rules))
                  SizedBox(
                    width: ProjectShelf.desktopWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: t.outlineVariant),
                        ),
                      ),
                      child: const RulesPanel(),
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      const TopBar(isDesktop: true),
                      Expanded(child: _screen(s, wide: true)),
                    ],
                  ),
                ),
              ],
            ),
            ..._overlays(s, wide: true),
          ],
        ),
      ),
    );
  }
}
