import 'package:flutter/material.dart';

import 'models/bridge.dart';
import 'screens/home_scaffold.dart';
import 'state/app_state.dart';
import 'state/persistence.dart';
import 'state/scope.dart';
import 'theme/schemes.dart';
import 'theme/tokens.dart';

/// Root of the Himark Editor. Owns the single [AppState], resolves the active
/// colour scheme and theme (dark / light / system) into a [HimarkTokens] set,
/// and republishes both through a [HimarkScope] on every change.
///
/// [bridge] is the language bridge to the real engines and [store] is where
/// the session is kept between runs; both default to the live implementation
/// and are injected only by tests.
class HimarkApp extends StatefulWidget {
  const HimarkApp({super.key, this.bridge, this.store});

  final Bridge? bridge;
  final Store? store;

  @override
  State<HimarkApp> createState() => _HimarkAppState();
}

class _HimarkAppState extends State<HimarkApp> {
  late final AppState _state = AppState(
    bridge: widget.bridge,
    store: widget.store,
  );

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  ThemeMode _themeMode() {
    switch (_state.theme) {
      case ThemeChoice.dark:
        return ThemeMode.dark;
      case ThemeChoice.light:
        return ThemeMode.light;
      case ThemeChoice.system:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        return MaterialApp(
          title: 'Himark Editor',
          debugShowCheckedModeBanner: false,
          themeMode: _themeMode(),
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: tokensFor(
              _state.scheme,
              Brightness.light,
            ).surface,
            fontFamily: kSansFamily,
            fontFamilyFallback: kSansFallback,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: tokensFor(
              _state.scheme,
              Brightness.dark,
            ).surface,
            fontFamily: kSansFamily,
            fontFamilyFallback: kSansFallback,
          ),
          home: Builder(
            builder: (context) {
              final resolved = _state.theme == ThemeChoice.system
                  ? MediaQuery.platformBrightnessOf(context)
                  : (_state.theme == ThemeChoice.dark
                        ? Brightness.dark
                        : Brightness.light);
              final tokens = tokensFor(_state.scheme, resolved);
              return HimarkScope(
                state: _state,
                tokens: tokens,
                brightness: resolved,
                child: const HomeScaffold(),
              );
            },
          ),
        );
      },
    );
  }
}
