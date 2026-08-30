import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ues_rutas/core/theme.dart';
import 'package:ues_rutas/data/campus_repository.dart';
import 'package:ues_rutas/data/models.dart';
import 'package:ues_rutas/data/providers.dart';
import 'package:ues_rutas/features/ajustes/ajustes_screen.dart';
import 'package:ues_rutas/features/ajustes/settings_controller.dart';
import 'package:ues_rutas/features/credencializacion/credencializacion_screen.dart';
import 'package:ues_rutas/features/notificaciones/notificaciones_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CampusData data;
  late SharedPreferences prefs;
  late Set<String> teselas;

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    data = await const SeedCampusRepository().cargar();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final raw = await rootBundle.loadString('assets/tiles/manifest.json');
    teselas = (jsonDecode(raw) as List).cast<String>().toSet();
  });

  Future<void> bombear(WidgetTester tester, Widget pantalla) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          campusDataProvider.overrideWith((ref) => data),
          teselasBundledProvider.overrideWithValue(teselas),
        ],
        child: MaterialApp(
          theme: UesTheme.light,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: pantalla,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('directrices de accesibilidad', () {
    testWidgets('Ajustes: toques, etiquetas y contraste', (tester) async {
      final handle = tester.ensureSemantics();
      await bombear(tester, const AjustesScreen());

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('Notificaciones: toques y etiquetas', (tester) async {
      final handle = tester.ensureSemantics();
      await bombear(tester, const NotificacionesScreen());

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('etiquetas semánticas concretas', () {
    testWidgets('la credencial se anuncia como una sola tarjeta',
        (tester) async {
      final handle = tester.ensureSemantics();
      await bombear(tester, const CredencializacionScreen());

      expect(
        find.bySemanticsLabel(RegExp('Credencial digital de ejemplo')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  test('Lugar.miUbicacion sigue construyéndose (sanidad)', () {
    final l = Lugar.miUbicacion(const LatLng(29.12, -110.96));
    expect(l.id, Lugar.idMiUbicacion);
  });
}
