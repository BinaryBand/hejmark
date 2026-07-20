import 'package:flutter/material.dart';

import 'screens/home_scaffold.dart';
import 'state/app_state.dart';
import 'state/scope.dart';
import 'theme/tokens.dart';

/// Root of the Himark Editor. Owns the single [AppState], resolves the active
/// theme (dark / light / system) into a [HimarkTokens] set, and republishes
/// both through a [HimarkScope] on every change.
class HimarkApp extends StatefulWidget {
  const HimarkApp({super.key});

  @override
  State<HimarkApp> createState() => _HimarkAppState();
}

class _HimarkAppState extends State<HimarkApp> {
  final AppState _state = AppState();

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
            scaffoldBackgroundColor: lightTokens.surface,
            fontFamily: kSansFamily,
            fontFamilyFallback: kSansFallback,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: darkTokens.surface,
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
              final tokens = resolved == Brightness.dark
                  ? darkTokens
                  : lightTokens;
              return HimarkScope(
                state: _state,
                tokens: tokens,
                child: const HomeScaffold(),
              );
            },
          ),
        );
      },
    );
  }
}
