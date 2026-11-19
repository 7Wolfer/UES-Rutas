import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ues_rutas/data/campus_repository.dart';
import 'package:ues_rutas/data/geo.dart';
import 'package:ues_rutas/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('proyección local', () {
    const centro = Punto(29.1213, -110.9625);
    final geo = GeoLocal(centro);

    test('coincide con haversine a escala del campus (< 0.2 %)', () {
      final azar = math.Random(3);
      for (var i = 0; i < 300; i++) {
        final a = Punto(centro.lat + (azar.nextDouble() - .5) * .006,
            centro.lng + (azar.nextDouble() - .5) * .006);
        final b = Punto(centro.lat + (azar.nextDouble() - .5) * .006,
            centro.lng + (azar.nextDouble() - .5) * .006);
        final real = a.distanciaA(b);
        if (real < 20) continue;
        final plana = geo.aXY(a).distanciaA(geo.aXY(b));
        expect((plana - real).abs() / real, lessThan(0.002));
      }
    });

    test('ida y vuelta conserva el punto', () {
      const p = Punto(29.1221, -110.9611);
      final q = geo.aPunto(geo.aXY(p));
      expect(q.lat, closeTo(p.lat, 1e-9));
      expect(q.lng, closeTo(p.lng, 1e-9));
    });
  });

  group('rumbos', () {
    test('norte, este, sur y oeste', () {
      const o = PuntoXY(0, 0);
      expect(rumbo(o, const PuntoXY(0, 10)), closeTo(0, 1e-9));
      expect(rumbo(o, const PuntoXY(10, 0)), closeTo(90, 1e-9));
      expect(rumbo(o, const PuntoXY(0, -10)), closeTo(180, 1e-9));
      expect(rumbo(o, const PuntoXY(-10, 0)), closeTo(270, 1e-9));
    });

    test('diferencia angular normalizada; positivo = derecha', () {
      expect(difAngular(90, 0), 90);
      expect(difAngular(0, 90), -90);
      expect(difAngular(10, 350), closeTo(20, 1e-9));
      expect(difAngular(350, 10), closeTo(-20, 1e-9));
      expect(difAngular(180, 0), 180);
    });

    test('suavizado circular: 350° y 10° promedian en el norte', () {
      final s = RumboSuavizado(tau: 1);
      final t0 = DateTime(2026);
      s.agregar(350, t0);
      // dt = τ·ln 2 → mezcla 50/50: el promedio circular de 350° y 10° es 0°.
      final v = s.agregar(10, t0.add(const Duration(microseconds: 693147)))!;
      expect(difAngular(v, 0).abs(), lessThan(1));
    });
  });

  group('polilíneas', () {
    test('Douglas–Peucker quita el zigzag y conserva las anclas', () {
      final pts = [
        for (var i = 0; i <= 20; i++) PuntoXY(i * 4.0, i.isEven ? 0 : 1),
        const PuntoXY(80, 40),
      ];
      final quedan = douglasPeucker(pts, 3, anclas: {10});
      expect(quedan.first, 0);
      expect(quedan.last, pts.length - 1);
      expect(quedan, contains(10));
      expect(quedan, contains(20)); // la esquina real
      expect(quedan.length, lessThanOrEqualTo(5));
    });

    test('proyección acotada a los extremos', () {
      const a = PuntoXY(0, 0), b = PuntoXY(10, 0);
      final p = proyectarEnSegmento(const PuntoXY(5, 3), a, b);
      expect(p.t, closeTo(.5, 1e-9));
      expect(p.distancia, closeTo(3, 1e-9));
      final fuera = proyectarEnSegmento(const PuntoXY(-4, 3), a, b);
      expect(fuera.t, 0);
      expect(fuera.distancia, closeTo(5, 1e-9));
    });

    test('punto a cierta distancia sobre la polilínea', () {
      final pts = [const PuntoXY(0, 0), const PuntoXY(10, 0), const PuntoXY(10, 10)];
      final acum = acumulados(pts);
      expect(acum.last, 20);
      final m = puntoEnDistancia(pts, acum, 15);
      expect(m.x, closeTo(10, 1e-9));
      expect(m.y, closeTo(5, 1e-9));
    });
  });

  test('punto en polígono sobre el perímetro real del campus', () async {
    final data = await const SeedCampusRepository().cargar();
    final geo = GeoLocal(data.info.centro);
    final per = [for (final p in data.info.perimetro) geo.aXY(p)];
    expect(puntoEnPoligono(geo.aXY(data.info.centro), per), isTrue);
    expect(puntoEnPoligono(geo.aXY(const Punto(29.1150, -110.9625)), per),
        isFalse);
    final a = data.lugar('lug_edificio_a')!;
    expect(
        distanciaAPoligono(
            geo.aXY(a.punto), [for (final p in a.poligono!) geo.aXY(p)]),
        lessThan(30));
  });
}
