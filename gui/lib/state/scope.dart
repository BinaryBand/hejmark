import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import 'app_state.dart';

/// Provides the [AppState] and the resolved [HimarkTokens] to the widget tree.
/// The root rebuilds this on every state change (via a [ListenableBuilder]),
/// so descendants can read both with `HimarkScope.of(context)`.
class HimarkScope extends InheritedWidget {
  const HimarkScope({
    required this.state,
    required this.tokens,
    required super.child,
    super.key,
  });

  final AppState state;
  final HimarkTokens tokens;

  static HimarkScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HimarkScope>();
    assert(scope != null, 'HimarkScope not found in context');
    return scope!;
  }

  static AppState stateOf(BuildContext context) => of(context).state;
  static HimarkTokens tokensOf(BuildContext context) => of(context).tokens;

  // [AppState] mutates in place and is republished on every `notifyListeners`
  // (via the root [ListenableBuilder]), so a rebuilt scope always reflects new
  // state even though the instance is identical. Always notify dependents.
  @override
  bool updateShouldNotify(HimarkScope oldWidget) => true;
}
