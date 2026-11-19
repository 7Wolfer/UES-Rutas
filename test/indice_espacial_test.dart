import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ues_rutas/data/campus_geo.dart';
import 'package:ues_rutas/data/campus_repository.dart';
import 'package:ues_rutas/data/geo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CampusGeo geo;

  setUpAll(() async {
    geo = CampusGeo(await const SeedCampusRepository().cargar());
  });

  test('nodo y arista más cercanos coinciden con la fuerza bruta', () {
    final azar = math.Random(11);
    for (var i = 0; i < 2000; i++) {
      final p = PuntoXY((azar.nextDouble() - .5) * 700,
          (azar.nextDouble() - .5) * 500);

      var mejorN = -1;
      var mejorDn = double.infinity;
      for (var n = 0; n < geo.nodoX.length; n++) {
        final d = p.distanciaA(geo.xyNodo(n));
        if (d < mejorDn) {
          mejorDn = d;
          mejorN = n;
        }
      }
      final n = geo.indice.nodoMasCercano(p.x, p.y)!;
      expect(p.distanciaA(geo.xyNodo(n)), closeTo(mejorDn, 1e-9),
          reason: 'nodo $n vs $mejorN');

      var mejorDe = double.infinity;
      for (var e = 0; e < geo.aristaA.length; e++) {
        final d = proyectarEnSegmento(
                p, geo.xyNodo(geo.aristaA[e]), geo.xyNodo(geo.aristaB[e]))
            .distancia;
        if (d < mejorDe) mejorDe = d;
      }
      final pr = geo.indice.aristaMasCercana(p.x, p.y, radioMax: 1000);
      if (mejorDe <= 1000) {
        expect(pr, isNotNull);
        expect(pr!.distancia, closeTo(mejorDe, 1e-9));
      }
      final cerca = geo.indice.aristaMasCercana(p.x, p.y, radioMax: 5);
      expect(cerca == null, mejorDe > 5);
    }
  });
}
