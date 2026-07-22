import 'package:flutter/material.dart';

import '../models/cheat.dart';
import '../state/scope.dart';
import '../theme/tokens.dart';

/// The Himark syntax cheat sheet: a scrim plus a scrolling reference panel.
///
/// It docks differently by width, following the design: a 460px drawer against
/// the right edge where there is room beside the editor, and a near-full-height
/// bottom sheet where there is not. Both are the same content — only the frame
/// and the entrance differ.
class CheatSheet extends StatelessWidget {
  const CheatSheet({required this.isDesktop, super.key});

  /// The design's own breakpoint for this panel is the shell's, so the caller
  /// passes the answer rather than measuring a second time.
  final bool isDesktop;

  static const double _drawerWidth = 460;

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;
    if (!s.cheatOpen) return const SizedBox.shrink();

    final panel = Material(
      color: t.surfaceContainerHigh,
      borderRadius: isDesktop
          ? null
          : const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _header(t, s.closeCheat),
          Expanded(child: _body(t)),
        ],
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: s.closeCheat,
            child: Container(color: Colors.black.withValues(alpha: 0.45)),
          ),
        ),
        if (isDesktop)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: _drawerWidth,
            child: _slideIn(
              horizontal: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: t.outlineVariant)),
                ),
                child: panel,
              ),
            ),
          )
        else
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            // The design leaves 7% of the shell showing above the sheet, so the
            // scrim behind it is visibly tappable rather than a hairline.
            top: MediaQuery.sizeOf(context).height * 0.07,
            child: _slideIn(horizontal: false, child: panel),
          ),
      ],
    );
  }

  Widget _header(HimarkTokens t, VoidCallback close) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Himark cheat sheet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                    color: t.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Quick reference for writing '),
                      TextSpan(
                        text: '.hmk',
                        style: mono(
                          fontSize: 12,
                          color: t.onSurfaceVariant,
                          height: 1.2,
                        ),
                      ),
                      const TextSpan(text: ' source'),
                    ],
                  ),
                  style: TextStyle(fontSize: 12, color: t.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            height: 40,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: close,
                child: Center(
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: t.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(HimarkTokens t) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        for (final section in kCheatSheet) ..._section(t, section),
      ],
    );
  }

  List<Widget> _section(HimarkTokens t, CheatSection section) {
    return <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(
          section.heading.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: t.primary,
          ),
        ),
      ),
      if (section.intro != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            section.intro!,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: t.onSurfaceVariant,
            ),
          ),
        ),
      for (final row in section.rows) _row(t, row),
      if (section.code != null)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: t.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
          ),
          // A worked example is column-aligned, so it scrolls sideways rather
          // than wrapping — a wrapped one stops being a worked example.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              section.code!,
              style: mono(
                fontSize: 11.5,
                color: t.onSurface,
                height: 1.65,
              ),
            ),
          ),
        ),
      if (section.note != null)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: t.outlineVariant, width: 2),
            ),
          ),
          child: Text(
            section.note!,
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: t.onSurfaceVariant,
            ),
          ),
        ),
    ];
  }

  Widget _row(HimarkTokens t, CheatRow row) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: t.surfaceContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                row.code,
                style: mono(
                  fontSize: 12,
                  color: t.syntax.identifier,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text.rich(
            TextSpan(
              children: [
                if (row.name != null)
                  TextSpan(
                    text: '${row.name} — ',
                    style: TextStyle(
                      color: t.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                TextSpan(text: row.desc),
              ],
            ),
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: t.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _slideIn({required bool horizontal, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      builder: (context, v, c) => Transform.translate(
        offset: horizontal
            ? Offset(v * _drawerWidth, 0)
            : Offset(0, v * 80),
        child: horizontal ? c : Opacity(opacity: 1 - v, child: c),
      ),
      child: child,
    );
  }
}
