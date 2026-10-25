import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ues_rutas/data/campus_repository.dart';
import 'package:ues_rutas/data/models.dart';
import 'package:ues_rutas/data/routing.dart';

/// Banco de rendimiento del ruteo. No impone límites estrictos (la máquina de
/// pruebas varía); imprime los tiempos para comparar antes/después de cada
/// cambio en el motor y solo falla ante una regresión grosera.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('banco: carga del campus y rutas entre todos los pares', () async {
    final relojCarga = Stopwatch()..start();
    final data = await const SeedCampusRepository().cargar();
    relojCarga.stop();

    final motor = MotorRutas(data);
    final lugares = data.lugares;

    for (final accesible in [false, true]) {
      // Calentamiento para que el JIT no sesgue la primera medición.
      motor.calcular(
          origen: lugares.first, destino: lugares.last, accesible: accesible);

      var pares = 0;
      var conRuta = 0;
      final reloj = Stopwatch()..start();
      for (final o in lugares) {
        for (final d in lugares) {
          if (identical(o, d)) continue;
          pares++;
          final r = motor.calcular(origen: o, destino: d, accesible: accesible);
          if (!r.sinRuta) conRuta++;
        }
      }
      reloj.stop();
      final msPorRuta = reloj.elapsedMicroseconds / 1000 / pares;
      debugPrint('[banco] ${accesible ? 'accesible' : 'normal   '}: '
          '$pares pares, $conRuta con ruta, '
          '${msPorRuta.toStringAsFixed(2)} ms/ruta');
      expect(msPorRuta, lessThan(250), reason: 'regresión grosera del motor');
    }

    // Origen arbitrario (como "Mi ubicación"): incluye buscar el nodo cercano.
    final reloj = Stopwatch()..start();
    var n = 0;
    for (var i = 0; i < 40; i++) {
      final p = Punto(29.1205 + i * 0.00004, -110.9628 + i * 0.00003);
      motor.calcular(
        origen: Lugar(
          id: Lugar.idMiUbicacion,
          nombre: 'Mi ubicación',
          categoria: lugares.first.categoria,
          punto: p,
          accesible: true,
        ),
        destino: lugares[i % lugares.length],
        accesible: false,
      );
      n++;
    }
    reloj.stop();
    debugPrint('[banco] desde un punto arbitrario: '
        '${(reloj.elapsedMicroseconds / 1000 / n).toStringAsFixed(2)} ms/ruta');
    debugPrint('[banco] carga del campus (4 JSON): '
        '${relojCarga.elapsedMilliseconds} ms');
  });
}
