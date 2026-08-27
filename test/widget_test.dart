import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ues_rutas/core/router.dart';
import 'package:ues_rutas/core/theme.dart';
import 'package:ues_rutas/features/ajustes/settings_controller.dart';

void main() {
  testWidgets('la app arranca y muestra la pantalla de inicio', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            routerConfig: ref.watch(routerProvider),
            theme: UesTheme.light,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('UES Rutas'), findsWidgets);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Mapa'), findsOneWidget);
  });
}
