import 'package:flutter/material.dart';

import '../models/expand_examples.dart';
import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// The Expand screen: denotes a Himark expression into its ordered entries. The
/// prototype has no live engine, so an example strip selects from a curated
/// library ([kExpandExamples]); the expression field mirrors the selection.
class ExpandScreen extends StatefulWidget {
  const ExpandScreen({super.key});

  @override
  State<ExpandScreen> createState() => _ExpandScreenState();
}

class _ExpandScreenState extends State<ExpandScreen> {
  final TextEditingController _controller = TextEditingController();
  int? _syncedIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sync(int index) {
    if (index != _syncedIndex) {
      _syncedIndex = index;
      final text = kExpandExamples[index].expression;
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _onExpressionChanged(AppState s, String value) {
    final trimmed = value.trim();
    for (var i = 0; i < kExpandExamples.length; i++) {
      if (kExpandExamples[i].expression == trimmed && i != s.expandIndex) {
        _syncedIndex = i; // avoid clobbering the caret on the next sync
        s.setExpandExample(i);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = HimarkScope.of(context);
    final s = scope.state;
    final t = scope.tokens;
    final index = s.expandIndex.clamp(0, kExpandExamples.length - 1);
    _sync(index);
    final ex = kExpandExamples[index];

    return Container(
      color: t.surface,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(t, ex),
            _expressionField(s, t),
            _strip(s, t, index),
            _card(t, ex),
          ],
        ),
      ),
    );
  }

  Widget _header(HimarkTokens t, ExpandExample ex) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel('Expand', tokens: t),
                const SizedBox(height: 2),
                Text(
                  'Denotation of an expression',
                  style: TextStyle(fontSize: 11.5, color: t.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: t.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'order type ${ex.orderType}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: t.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expressionField(AppState s, HimarkTokens t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel('Expression', tokens: t),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: t.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.outlineVariant),
            ),
            child: TextField(
              controller: _controller,
              onChanged: (v) => _onExpressionChanged(s, v),
              maxLines: null,
              cursorColor: t.primary,
              style: mono(
                fontSize: s.editorFontSize.toDouble(),
                color: t.onSurface,
                height: 1.4,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _strip(AppState s, HimarkTokens t, int index) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: kExpandExamples.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == index;
          return GestureDetector(
            onTap: () => s.setExpandExample(i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? t.primaryContainer : t.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                kExpandExamples[i].chipLabel,
                style: mono(
                  fontSize: 13,
                  color: selected ? t.onPrimaryContainer : t.onSurfaceVariant,
                  height: 1.2,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _card(HimarkTokens t, ExpandExample ex) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ex.title} — order type ${ex.orderType}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: t.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.outlineVariant),
            ),
            child: Text(
              ex.description,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: t.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in ex.entries) _entryChip(t, entry),
              if (ex.infinite) _ellipsis(t),
            ],
          ),
        ],
      ),
    );
  }

  Widget _entryChip(HimarkTokens t, ExpandEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: t.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: t.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '${entry.index}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: t.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          for (final face in entry.faces) ...[
            Text(
              face.text,
              style:
                  mono(
                    fontSize: 14,
                    color: face.primary ? t.onSurface : t.onSurfaceVariant,
                    height: 1.0,
                  ).copyWith(
                    fontWeight: face.primary
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  Widget _ellipsis(HimarkTokens t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      alignment: Alignment.center,
      child: Text(
        '…',
        style: TextStyle(fontSize: 18, height: 1.0, color: t.onSurfaceVariant),
      ),
    );
  }
}
