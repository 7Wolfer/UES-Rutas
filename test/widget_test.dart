import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ues_rutas/core/theme.dart';
import 'package:ues_rutas/features/ajustes/settings_controller.dart';
import 'package:ues_rutas/features/credencializacion/credencializacion_screen.dart';

void main() {
  testWidgets('Credencialización muestra sus pestañas y el calendario UES',
      (tester) async {
    await initializeDateFormatting('es', null);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: UesTheme.light,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const CredencializacionScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Credencial'), findsOneWidget);
    expect(find.text('Calendario'), findsOneWidget);
    expect(find.text('Requisitos'), findsOneWidget);
    expect(find.textContaining('PROTOTIPO'), findsOneWidget);
    expect(find.textContaining('Universidad Estatal de Sonora'), findsWidgets);
  });
}
