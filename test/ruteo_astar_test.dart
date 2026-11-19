import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ues_rutas/data/campus_repository.dart';
import 'package:ues_rutas/data/models.dart';
import 'package:ues_rutas/data/routing.dart';

import 'support/dijkstra_referencia.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CampusData data;
  late MotorRutas motor;

  setUpAll(() async {
    data = await const SeedCampusRepository().cargar();
    motor = MotorRutas(data);
  });

  test('A* da el mismo costo que Dijkstra en todos los pares y modos', () {
    for (final accesible in [false, true]) {
      for (final o in data.lugares) {
        final ref = costosDijkstra(data, 'n_${o.id}', accesible: accesible);
        for (final d in data.lugares) {
          if (o.id == d.id) continue;
          final r = motor.calcular(origen: o, destino: d, accesible: accesible);
          final esperado = ref['n_${d.id}'];
          if (esperado == null) {
            expect(r.sinRuta, isTrue, reason: '${o.id} → ${d.id}');
            continue;
          }
          expect(r.sinRuta, isFalse, reason: '${o.id} → ${d.id}');
          expect(r.costo, closeTo(esperado, 1e-6),
              reason: '${o.id} → ${d.id} (accesible: $accesible)');
        }
      }
    }
  });

  test('la distancia es la suma real de tramos, sin penalizaciones', () {
    for (final o in data.lugares.take(12)) {
      for (final d in data.lugares.reversed.take(12)) {
        if (o.id == d.id) continue;
        final r = motor.calcular(origen: o, destino: d, accesible: false);
        var suma = 0.0;
        for (var i = 1; i < r.puntos.length; i++) {
          suma += r.puntos[i - 1].distanciaA(r.puntos[i]);
        }
        expect(r.distancia, closeTo(suma, 1e-6));
        expect(r.acumulado.length, r.puntos.length);
        expect(r.tipos.length, r.puntos.length - 1);
        for (var i = 1; i < r.acumulado.length; i++) {
          expect(r.acumulado[i], greaterThan(r.acumulado[i - 1]));
        }
        expect(r.costo, greaterThanOrEqualTo(r.distancia - 1e-6));
      }
    }
  });

  test('la ruta accesible nunca usa escaleras', () {
    for (final o in data.lugares) {
      for (final d in data.lugares) {
        if (o.id == d.id) continue;
        final r = motor.calcular(origen: o, destino: d, accesible: true);
        expect(r.usaEscaleras, isFalse, reason: '${o.id} → ${d.id}');
        expect(r.tipos.contains(TipoArista.escalera), isFalse);
      }
    }
  });

  test('desde puntos libres: arranca en el punto y se engancha a una arista',
      () {
    final azar = math.Random(7);
    final c = data.info.centro;
    final destino = data.lugar('lug_cafeteria_ues')!;
    var enganchadas = 0;
    for (var i = 0; i < 200; i++) {
      final p = LatLng(c.lat + (azar.nextDouble() - 0.5) * 0.004,
          c.lng + (azar.nextDouble() - 0.5) * 0.005);
      final r = motor.calcular(
          origen: Lugar.miUbicacion(p), destino: destino, accesible: false);
      expect(r.sinRuta, isFalse);
      expect(r.puntos.first.lat, p.latitude);
      expect(r.puntos.first.lng, p.longitude);
      expect(r.puntos.last, equals(r.nodos.last.punto));
      if (r.aproxOrigen <= MotorRutas.radioEnganche) enganchadas++;
    }
    expect(enganchadas, greaterThan(100));
  });

  test('sin vuelta en U al arrancar desde la mitad de un andador', () {
    // Punto sobre un andador: la ruta no debe ir hacia atrás para regresar.
    final destino = data.lugar('lug_edificio_h')!;
    final origen = data.lugar('lug_edificio_a')!;
    final base = motor.calcular(origen: origen, destino: destino, accesible: false);
    final medio = base.puntos[base.puntos.length ~/ 2];
    final r = motor.calcular(
      origen: Lugar.miUbicacion(LatLng(medio.lat, medio.lng)),
      destino: destino,
      accesible: false,
    );
    final restante = base.distancia - base.acumulado[base.puntos.length ~/ 2];
    expect(r.distancia, lessThan(restante + 12));
  });
}
