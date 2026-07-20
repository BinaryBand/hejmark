import 'package:flutter/material.dart';

/// Inline rename field used by tab chips and the project shelf. Auto-focuses
/// and selects its text, commits on submit / tap-outside, and cancels on Esc.
class RenameField extends StatefulWidget {
  const RenameField({
    required this.initial,
    required this.color,
    required this.onChanged,
    required this.onSubmit,
    required this.onCancel,
    this.fontSize = 13,
    super.key,
  });

  final String initial;
  final Color color;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final double fontSize;

  @override
  State<RenameField> createState() => _RenameFieldState();
}

class _RenameFieldState extends State<RenameField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.onChanged(widget.initial);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _c.selection = TextSelection(baseOffset: 0, extentOffset: _c.text.length);
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
    return TextField(
      controller: _c,
      focusNode: _focus,
      onChanged: widget.onChanged,
      onSubmitted: (_) => widget.onSubmit(),
      onTapOutside: (_) => widget.onSubmit(),
      cursorColor: widget.color,
      style: TextStyle(
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w600,
        color: widget.color,
      ),
      decoration: const InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
      ),
    );
  }
}
