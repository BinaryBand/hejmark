import 'package:flutter/material.dart';

import '../models/matcher.dart';
import '../models/project.dart';
import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/rename_field.dart';

/// The Test screen: a strip of test-string tabs, a code editor with a
/// line-number gutter (edit mode) or a match-highlighted read view (view mode),
/// and a collapsible output sheet listing the matches.
class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String? _syncedTabId;

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
    final s = scope.state;
    final t = scope.tokens;
    final project = s.cur;
    final active = project?.active;
    _syncController(active);

    return Container(
      color: t.surface,
      child: Column(
        children: [
          if (s.tabBarVisible) _tabStrip(context, s, t, project),
          Expanded(
            child: active == null
                ? EmptyState(
                    tokens: t,
                    icon: Icons.description_outlined,
                    title: 'No test string open',
                    hint: 'Create a test string to run your rules against it.',
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
                : _body(s, t, project!, active),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab strip
  // ---------------------------------------------------------------------------

  Widget _tabStrip(
    BuildContext context,
    AppState s,
    HimarkTokens t,
    Project? project,
  ) {
    final tabs = project?.tabs ?? const <TestString>[];
    final activeId = project?.activeTab;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.surfaceContainer,
        border: Border(bottom: BorderSide(color: t.outlineVariant)),
      ),
      child: Row(
        children: [
          CircleIconButton(
            icon: s.editMode ? Icons.edit : Icons.visibility_outlined,
            tooltip: s.editMode ? 'View mode' : 'Edit mode',
            background: t.surfaceContainerHigh,
            color: s.editMode ? t.primary : t.onSurfaceVariant,
            onTap: s.toggleEditMode,
          ),
          _vDivider(t),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in tabs) ...[
                    _tabChip(s, t, tab, tab.id == activeId),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          _vDivider(t),
          CircleIconButton(
            icon: Icons.add,
            tooltip: 'New test string',
            background: t.surfaceContainerHigh,
            color: t.onSurfaceVariant,
            onTap: s.addTab,
          ),
        ],
      ),
    );
  }

  Widget _vDivider(HimarkTokens t) => Container(
    width: 1,
    height: 24,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: t.outlineVariant,
  );

  Widget _tabChip(AppState s, HimarkTokens t, TestString tab, bool active) {
    if (s.isEditing(MenuScope.tab, tab.id)) {
      return Container(
        height: 40,
        padding: const EdgeInsets.only(left: 12, right: 6),
        decoration: BoxDecoration(
          color: t.primaryContainer,
          borderRadius: BorderRadius.circular(20),
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
        height: 40,
        padding: EdgeInsets.only(left: 14, right: active ? 6 : 14),
        decoration: BoxDecoration(
          color: active ? t.primaryContainer : t.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
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
            if (active)
              CircleIconButton(
                icon: Icons.more_horiz,
                size: 26,
                iconSize: 15,
                color: t.onPrimaryContainer,
                onTap: () => s.openMenu(MenuScope.tab, tab.id, tab.name),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Editor / read view + output sheet
  // ---------------------------------------------------------------------------

  Widget _body(AppState s, HimarkTokens t, Project project, TestString active) {
    final matches = computeMatches(
      active.content,
      project.rules,
      project.enabled,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final sheetHeight = s.sheetExpanded ? box.maxHeight * 0.46 : 45.0;
        return Column(
          children: [
            Expanded(
              child: s.editMode
                  ? _editor(s, t, active)
                  : _readView(s, t, active, matches),
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

  Widget _editor(AppState s, HimarkTokens t, TestString active) {
    final fs = s.editorFontSize.toDouble();
    final lineCount = (active.content.split('\n').length).clamp(1, 1 << 30);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Line-number gutter, translated to follow the editor's scroll.
        ClipRect(
          child: SizedBox(
            width: 34,
            child: Padding(
              padding: const EdgeInsets.only(top: 16, left: 16),
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
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              '$i',
                              textAlign: TextAlign.right,
                              style: mono(
                                fontSize: fs,
                                color: t.onSurfaceVariant,
                              ).copyWith(height: 1.7),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
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
    );
  }

  Widget _readView(
    AppState s,
    HimarkTokens t,
    TestString active,
    List<MatchRange> matches,
  ) {
    final fs = s.editorFontSize.toDouble();
    final content = active.content;
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var li = 0; li < lines.length; li++)
            _readLine(t, fs, lines[li], lineStarts[li], matches, glyphs),
        ],
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
      spans.add(
        TextSpan(
          text: glyphs(line.substring(a, b)),
          style: mono(
            fontSize: fs,
            color: t.markFg,
          ).copyWith(backgroundColor: t.markBg),
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
    final count = matches.length;
    final summary = count == 1 ? '1 match' : '$count matches';
    final active = s.cur?.active;
    final content = active?.content ?? '';

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
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.onSurfaceVariant,
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
            child: count == 0
                ? _sheetEmpty(t)
                : _matchList(s, t, matches, content),
          ),
      ],
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
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: t.primary,
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
