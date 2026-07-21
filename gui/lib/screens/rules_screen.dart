import 'package:flutter/material.dart';

import '../widgets/rules_panel.dart';

/// The mobile Rules destination. The panel is the whole screen here and the
/// desktop sidebar there, so the screen is only a placement.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) => const RulesPanel();
}
