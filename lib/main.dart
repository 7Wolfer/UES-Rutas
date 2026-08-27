import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'features/ajustes/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  if (AppConfig.supabaseConfigurado) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // Acepta tanto la "publishable key" nueva (sb_publishable_...) como la
      // "anon key" heredada (JWT) del panel de Supabase.
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const UesRutasApp(),
    ),
  );
}

class UesRutasApp extends ConsumerWidget {
  const UesRutasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: AppConfig.nombreApp,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: _quizaAltoContraste(UesTheme.light, settings.highContrast),
      darkTheme: _quizaAltoContraste(UesTheme.dark, settings.highContrast),
      themeMode: settings.themeMode,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(settings.textScale),
            highContrast: settings.highContrast || mq.highContrast,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  ThemeData _quizaAltoContraste(ThemeData base, bool alto) {
    if (!alto) return base;
    final cs = base.colorScheme;
    return base.copyWith(
      colorScheme: cs.copyWith(
        outline: cs.onSurface,
        outlineVariant: cs.onSurfaceVariant,
      ),
      dividerColor: cs.onSurface,
    );
  }
}
