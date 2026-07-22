import 'package:flutter/material.dart';

import '../models/rules.dart';
import '../theme/tokens.dart';

/// Renders a rule's Himark source as syntax-highlighted monospace text inside a
/// rounded surface, wrapping on any character.
class RuleCode extends StatelessWidget {
  const RuleCode({
    required this.spans,
    required this.fontSize,
    required this.tokens,
    super.key,
  });

  final List<CodeSpan> spans;
  final double fontSize;
  final HimarkTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.surfaceContainer,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            for (final span in spans)
              TextSpan(
                text: span.text,
                style: mono(fontSize: fontSize, color: span.color, height: 1.6),
              ),
          ],
        ),
      ),
    );
  }
}

/// [RuleCode]'s editing face: the same rounded block, with the highlighted
/// text swapped for a monospace field over the rule's real source.
///
/// It reports every keystroke rather than waiting for a submit, because the
/// engine pass behind it is already debounced — so a half-typed rule costs one
/// refusal in the output sheet, which is the feedback the editor is for. There
/// is no cancel: the field edits the rule in place, and `Undo` on a delete is
/// the only rewind this panel offers.
class RuleField extends StatefulWidget {
  const RuleField({
    required this.initial,
    required this.fontSize,
    required this.tokens,
    required this.onChanged,
    required this.onDone,
    super.key,
  });

  final String initial;
  final double fontSize;
  final HimarkTokens tokens;
  final ValueChanged<String> onChanged;
  final VoidCallback onDone;

  @override
  State<RuleField> createState() => _RuleFieldState();
}

class _RuleFieldState extends State<RuleField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _c.selection = TextSelection.collapsed(offset: _c.text.length);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: t.surfaceContainer,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: t.primary),
      ),
      child: TextField(
        controller: _c,
        focusNode: _focus,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: widget.onChanged,
        onSubmitted: (_) => widget.onDone(),
        onTapOutside: (_) => widget.onDone(),
        cursorColor: t.primary,
        style: mono(fontSize: widget.fontSize, color: t.onSurface, height: 1.6),
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
        ),
      ),
    );
  }
}
