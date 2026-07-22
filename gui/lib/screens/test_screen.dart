import 'package:flutter/material.dart';

import '../models/matcher.dart';
import '../models/project.dart';
import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/rename_field.dart';

/// Width of the line-number gutter, shared by the edit and read views so the
/// text does not shift when the mode flips.
const double _gutterWidth = 38;

/// The Test screen: a strip of test-string chips, the active string as either an
/// editable buffer or a match-highlighted read view, and a collapsible output
/// sheet listing what the engine found.
///
/// Both views carry the same gutter; the read view additionally paints each hit
/// in the colour of the rule that made it, so overlapping rule sets stay
/// legible.
class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String? _syncedTabId;

  /// The scope of the frame being built, so the highlight helpers below can
  /// resolve a rule's pinned swatch without every intermediate signature having
  /// to carry it. Only ever read from inside [build]'s synchronous call tree.
  HimarkScope? _scope;

  /// The colours the rule at [slot] paints its hits with — its pinned swatch if
  /// it has one, otherwise the slot its position cycles onto.
  RuleColors _slotColors(int slot) {
    final scope = _scope;
    if (scope == null) {
      return const RuleColors(
        dot: Color(0xFF000000),
        background: Color(0x00000000),
        foreground: Color(0xFF000000),
      );
    }
    final rules = scope.state.cur?.rules ?? const <Rule>[];
    return scope.colorsFor(slot < rules.length ? rules[slot] : null, slot);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Reset the editor's text when the active tab changes (tab switch, delete,
  /// undo), without disturbing the caret while the user is typing the same tab.
  void _syncController(TestString? active) {
    if (active?.id != _syncedTabId) {
      _syncedTabId = active?.id;
      final text = active?.content ?? '';
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    _scope = scope;
    final s = scope.state;
    final t = scope.tokens;
    final project = s.cur;
    final active = project?.active;
    _syncController(active);

    return Container(
      color: t.surface,
      child: Column(
        children: [
          if (s.tabBarVisible) _tabStrip(s, t, project),
          Expanded(
            child: active == null
                ? EmptyState(
                    tokens: t,
                    icon: Icons.description_outlined,
                    title: 'No test string open',
                    hint: 'Create a test string to run your rules against it.',
                    accent: true,
                    action: FilledButton(
                      onPressed: s.addTab,
                      style: FilledButton.styleFrom(
                        backgroundColor: t.primaryContainer,
                        foregroundColor: t.onPrimaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: const Text('New test string'),
                    ),
                  )
                : _body(s, t, active),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab strip
  // ---------------------------------------------------------------------------

  Widget _tabStrip(AppState s, HimarkTokens t, Project? project) {
    final tabs = project?.tabs ?? const <TestString>[];
    final activeId = project?.activeTab;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.surfaceContainer,
        border: Border(bottom: BorderSide(color: t.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in tabs) ...[
                    _tabChip(s, t, tab, tab.id == activeId),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          CircleIconButton(
            icon: Icons.add,
            size: 44,
            iconSize: 15,
            tooltip: 'New test string',
            background: t.primaryContainer,
            color: t.onPrimaryContainer,
            onTap: s.addTab,
          ),
        ],
      ),
    );
  }

  Widget _tabChip(AppState s, HimarkTokens t, TestString tab, bool active) {
    if (s.isEditing(MenuScope.tab, tab.id)) {
      return Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.only(left: 12, right: 6),
        decoration: BoxDecoration(
          color: t.primaryContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: SizedBox(
          width: 120,
          child: RenameField(
            initial: tab.name,
            color: t.onPrimaryContainer,
            onChanged: s.setEditingValue,
            onSubmit: s.commitRename,
            onCancel: s.cancelRename,
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => s.selectTab(tab.id),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: EdgeInsets.only(left: 14, right: active ? 6 : 14),
        decoration: BoxDecoration(
          color: active ? t.primaryContainer : t.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                tab.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? t.onPrimaryContainer : t.onSurfaceVariant,
                ),
              ),
            ),
            if (active) ...[
              const SizedBox(width: 4),
              CircleIconButton(
                icon: Icons.more_horiz,
                size: 32,
                iconSize: 14,
                tooltip: 'More',
                color: t.onPrimaryContainer,
                onTap: () => s.openMenu(MenuScope.tab, tab.id, tab.name),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Editor / read view + output sheet
  // ---------------------------------------------------------------------------

  Widget _body(AppState s, HimarkTokens t, TestString active) {
    // Matches come live from the Python parser + Rust engine bridge, recomputed
    // (debounced) by AppState whenever the text or rules change. In run mode
    // the read view shows the rewritten document instead — a run has no spans
    // to paint, its answer *is* the text.
    final matches = s.runMode ? const <MatchRange>[] : s.matches;
    final readText = s.runMode
        ? (s.runDocument ?? active.content)
        : active.content;
    return LayoutBuilder(
      builder: (context, box) {
        final sheetHeight = s.sheetExpanded ? box.maxHeight * 0.46 : 45.0;
        return Column(
          children: [
            Expanded(
              child: s.editMode
                  ? _editor(s, t, active)
                  : _readView(s, t, readText, matches),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.ease,
              height: sheetHeight,
              decoration: BoxDecoration(
                color: t.surfaceContainerLow,
                border: Border(top: BorderSide(color: t.outlineVariant)),
              ),
              child: _sheet(s, t, matches),
            ),
          ],
        );
      },
    );
  }

  /// The gutter's chrome — the numbers are supplied by each view, because the
  /// editor translates them under a clip while the read view scrolls them.
  Widget _gutterFrame(HimarkTokens t, {required Widget child}) {
    return Container(
      width: _gutterWidth,
      decoration: BoxDecoration(
        color: t.surfaceContainerLowest,
        border: Border(right: BorderSide(color: t.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 10, 16),
      child: child,
    );
  }

  Widget _lineNumber(HimarkTokens t, double fs, int n) => SizedBox(
    width: double.infinity,
    child: Text(
      '$n',
      textAlign: TextAlign.right,
      style: mono(fontSize: fs, color: t.onSurfaceVariant),
    ),
  );

  Widget _editor(AppState s, HimarkTokens t, TestString active) {
    final fs = s.editorFontSize.toDouble();
    final lineCount = active.content.split('\n').length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surfaceBright,
        border: Border(top: BorderSide(color: t.primary, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The gutter is a fixed column whose numbers ride the editor's scroll.
          ClipRect(
            child: _gutterFrame(
              t,
              child: AnimatedBuilder(
                animation: _scroll,
                builder: (context, _) {
                  final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                  return Transform.translate(
                    offset: Offset(0, -offset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 1; i <= lineCount; i++)
                          _lineNumber(t, fs, i),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 16, 16),
              child: TextField(
                controller: _controller,
                scrollController: _scroll,
                onChanged: s.setActiveContent,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                cursorColor: t.primary,
                keyboardType: TextInputType.multiline,
                style: mono(fontSize: fs, color: t.onSurface),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Type or paste text to test…',
                  hintStyle: mono(fontSize: fs, color: t.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readView(
    AppState s,
    HimarkTokens t,
    String content,
    List<MatchRange> matches,
  ) {
    final fs = s.editorFontSize.toDouble();
    final lines = content.split('\n');

    // Offset of each line start.
    final lineStarts = <int>[];
    var acc = 0;
    for (final line in lines) {
      lineStarts.add(acc);
      acc += line.length + 1;
    }

    String glyphs(String raw) =>
        s.showWhitespace ? raw.replaceAll(' ', '·').replaceAll('\t', '→') : raw;

    // Gutter and text scroll as one column, so a short document still shows the
    // gutter's full-height band.
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _gutterFrame(
                    t,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 1; i <= lines.length; i++)
                          _lineNumber(t, fs, i),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var li = 0; li < lines.length; li++)
                            _readLine(
                              t,
                              fs,
                              lines[li],
                              lineStarts[li],
                              matches,
                              glyphs,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _readLine(
    HimarkTokens t,
    double fs,
    String line,
    int lineStart,
    List<MatchRange> matches,
    String Function(String) glyphs,
  ) {
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final m in matches) {
      final rs = m.start - lineStart;
      final re = m.end - lineStart;
      if (re <= 0 || rs >= line.length) continue;
      final a = rs.clamp(0, line.length);
      final b = re.clamp(0, line.length);
      if (a > cursor) {
        spans.add(TextSpan(text: glyphs(line.substring(cursor, a))));
      }
      final colors = _slotColors(m.slot);
      spans.add(
        TextSpan(
          text: glyphs(line.substring(a, b)),
          style: mono(
            fontSize: fs,
            color: colors.foreground,
          ).copyWith(backgroundColor: colors.background),
        ),
      );
      cursor = b;
    }
    if (cursor < line.length) {
      spans.add(TextSpan(text: glyphs(line.substring(cursor))));
    }
    if (spans.isEmpty) spans.add(const TextSpan(text: ' '));

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: fs * 1.7),
      child: Text.rich(
        TextSpan(children: spans),
        style: mono(fontSize: fs, color: t.onSurface),
      ),
    );
  }

  Widget _sheet(AppState s, HimarkTokens t, List<MatchRange> matches) {
    final summary = s.matchSummary;
    final isError = s.engine == EngineState.error;
    final content = s.cur?.active?.content ?? '';

    return Column(
      children: [
        GestureDetector(
          onTap: s.toggleSheet,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 44,
            child: Stack(
              children: [
                Positioned(
                  top: 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isError ? t.error : t.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: s.sheetExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: t.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (s.sheetExpanded)
          Expanded(
            child: s.runMode
                ? _sheetRun(s, t)
                : matches.isEmpty
                ? _sheetEmpty(t)
                : _matchList(s, t, matches, content),
          ),
      ],
    );
  }

  Widget _sheetRun(AppState s, HimarkTokens t) {
    final isError = s.engine == EngineState.error;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.outlineVariant)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isError ? 'Run failed' : 'Run mode',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isError ? t.error : t.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isError
                    ? (s.engineError ?? 'Engine error')
                    : 'The enabled rules run in order as one script; the view '
                          'shows the rewritten document. Switch to edit mode '
                          'to change the input.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: t.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetEmpty(HimarkTokens t) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.outlineVariant)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No matches',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enable a rule or edit the text to find matches.',
              style: TextStyle(fontSize: 11.5, color: t.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _matchList(
    AppState s,
    HimarkTokens t,
    List<MatchRange> matches,
    String content,
  ) {
    final fs = s.editorFontSize.toDouble();
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.outlineVariant)),
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: matches.length,
        separatorBuilder: (_, _) => Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: t.outlineVariant,
        ),
        itemBuilder: (context, i) {
          final m = matches[i];
          return Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _slotColors(m.slot).dot,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    m.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono(fontSize: fs, color: t.onSurface, height: 1.2),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '[${m.start}–${m.end}]',
                      style: TextStyle(fontSize: 11, color: t.onSurfaceVariant),
                    ),
                    Text(
                      posOf(content, m.start),
                      style: TextStyle(fontSize: 11, color: t.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
