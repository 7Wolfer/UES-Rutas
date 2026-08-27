import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/providers.dart';
import 'features/ajustes/settings_controller.dart';
import 'services/notificaciones_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fuentes locales (sin descargas en runtime).
  GoogleFonts.config.allowRuntimeFetching =
      true; // TODO Fase C: empaquetar .ttf

  await initializeDateFormatting('es', null);

  final prefs = await SharedPreferences.getInstance();

  if (AppConfig.supabaseConfigurado) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  if (!kIsWeb) {
    unawaited(NotificacionesService.instance.init());
  }

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const UesRutasApp(),
    ),
  );
}

class UesRutasApp extends ConsumerStatefulWidget {
  const UesRutasApp({super.key});

  @override
  ConsumerState<UesRutasApp> createState() => _UesRutasAppState();
}

class _UesRutasAppState extends ConsumerState<UesRutasApp> {
  @override
  void initState() {
    super.initState();
    // Aviso local si hay algo nuevo sin leer al abrir la app.
    WidgetsBinding.instance.addPostFrameCallback((_) => _avisarNovedades());
  }

  Future<void> _avisarNovedades() async {
    final s = ref.read(settingsProvider);
    if (!s.notificaciones || kIsWeb) return;
    final avisos = await ref.read(avisosProvider.future);
    final leidos = ref.read(avisosLeidosProvider);
    final nuevos = avisos.where((a) => !leidos.contains(a.id)).toList();
    if (nuevos.isEmpty) return;
    final permitido = await NotificacionesService.instance.pedirPermiso();
    if (!permitido) return;
    final a = nuevos.first;
    await NotificacionesService.instance.mostrar(
      id: a.id.hashCode,
      titulo: nuevos.length == 1 ? a.titulo : '${nuevos.length} avisos nuevos',
      cuerpo: a.cuerpo,
      payload: '/notificaciones',
    );
  }

  @override
  Widget build(BuildContext context) {
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
