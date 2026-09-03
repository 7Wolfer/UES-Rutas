import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ues_rutas/data/busqueda.dart';
import 'package:ues_rutas/data/campus_repository.dart';
import 'package:ues_rutas/data/models.dart';
import 'package:ues_rutas/data/routing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CampusData data;
  late MotorRutas motor;

  setUpAll(() async {
    data = await const SeedCampusRepository().cargar();
    motor = MotorRutas(data);
  });

  test('el catálogo de prueba carga con contenido real del campus', () {
    expect(data.lugares.length, greaterThan(25));
    expect(data.docentes, isNotEmpty);
    expect(data.nodos, isNotEmpty);
    expect(data.aristas, isNotEmpty);
    expect(data.info.perimetro.length, greaterThan(4));
    expect(data.lugares.any((l) => l.nombre.contains('Cafetería')), isTrue);
    expect(
        data.lugares.any((l) => l.nombre == 'Aula Magna / Biblioteca'), isTrue);
  });

  test('todas las coordenadas caen dentro del campus de Hermosillo', () {
    for (final l in data.lugares) {
      expect(l.punto.lat, inInclusiveRange(29.118, 29.126));
      expect(l.punto.lng, inInclusiveRange(-110.967, -110.958));
    }
  });

  test('todas las aristas referencian nodos existentes', () {
    final ids = {for (final n in data.nodos) n.id};
    for (final a in data.aristas) {
      expect(ids.contains(a.a), isTrue, reason: 'nodo ${a.a}');
      expect(ids.contains(a.b), isTrue, reason: 'nodo ${a.b}');
    }
  });

  test('las asignaciones apuntan a lugares reales', () {
    for (final d in data.docentes) {
      for (final asg in d.asignaciones) {
        expect(data.lugar(asg.lugarId), isNotNull,
            reason: '${d.nombre} → ${asg.lugarId}');
      }
    }
  });

  group('búsqueda universal', () {
    test('encuentra a un docente por apellido', () {
      final r = buscar(data, 'martinez');
      expect(r.first.tipo, TipoResultado.docente);
      expect(r.first.titulo, contains('Martínez'));
    });

    test('encuentra un edificio', () {
      expect(buscar(data, 'biblioteca'), isNotEmpty);
      expect(buscar(data, 'gimnasio').any((x) => x.titulo.contains('Gimnasio')),
          isTrue);
    });

    test('es insensible a acentos', () {
      expect(buscar(data, 'cafeteria'), isNotEmpty);
      expect(buscar(data, 'Cafetería'), isNotEmpty);
    });

    test('cada resultado abre una ficha válida', () {
      for (final q in ['edificio', 'salud', 'estacionamiento', 'soto']) {
        for (final r in buscar(data, q)) {
          if (r.tipo == TipoResultado.docente) {
            expect(data.docente(r.id), isNotNull);
          } else {
            expect(data.lugar(r.id), isNotNull);
          }
        }
      }
    });
  });

  group('ruteo peatonal', () {
    test('traza una ruta con distancia y pasos', () {
      final origen = data.lugar('lug_acceso_principal')!;
      final destino = data.lugar('lug_aula_magna_biblioteca')!;
      final ruta =
          motor.calcular(origen: origen, destino: destino, accesible: false);
      expect(ruta.sinRuta, isFalse);
      expect(ruta.distancia, greaterThan(0));
      expect(ruta.puntos.length, greaterThan(2));
      final pasos = motor.describir(ruta, origen: origen, destino: destino);
      expect(pasos.first.texto, contains('Sales de'));
      expect(pasos.last.texto, contains('Llegas a'));
    });

    test('el acceso poniente no es accesible; existe alternativa', () {
      final poniente = data.lugar('lug_acceso_poniente')!;
      expect(poniente.accesible, isFalse);
    });

    test('hay ruta entre edificios principales', () {
      final ids = [
        'lug_edificio_a',
        'lug_centro_de_computo',
        'lug_cafeteria_ues',
        'lug_gimnasio_ues',
      ];
      for (final a in ids) {
        for (final b in ids) {
          if (a == b) continue;
          final r = motor.calcular(
            origen: data.lugar(a)!,
            destino: data.lugar(b)!,
            accesible: false,
          );
          expect(r.sinRuta, isFalse, reason: 'sin ruta $a → $b');
        }
      }
    });
  });

  group('ruta desde la ubicación del usuario', () {
    test('traza ruta desde un punto arbitrario y la nombra "Mi ubicación"', () {
      final origen = Lugar.miUbicacion(const LatLng(29.1214, -110.9625));
      final destino = data.lugar('lug_aula_magna_biblioteca')!;
      final ruta =
          motor.calcular(origen: origen, destino: destino, accesible: false);

      expect(ruta.sinRuta, isFalse);
      expect(ruta.distancia, greaterThan(0));
      // La polilínea arranca exactamente en el punto real del usuario.
      expect(ruta.puntos.first.lat, origen.punto.lat);
      expect(ruta.puntos.first.lng, origen.punto.lng);

      final pasos = motor.describir(ruta, origen: origen, destino: destino);
      expect(pasos.first.texto, contains('Mi ubicación'));
    });

    test('aproxOrigen refleja la distancia a la red peatonal', () {
      // ~700 m al sur del campus: lejos de cualquier nodo del grafo.
      final lejos = Lugar.miUbicacion(const LatLng(29.1150, -110.9625));
      final destino = data.lugar('lug_aula_magna_biblioteca')!;
      final ruta =
          motor.calcular(origen: lejos, destino: destino, accesible: false);

      expect(ruta.sinRuta, isFalse);
      expect(ruta.aproxOrigen, greaterThan(150));
      // La distancia total incluye ese tramo de aproximación.
      expect(ruta.distancia, greaterThan(ruta.aproxOrigen));
    });

    test('entre dos lugares la ruta arranca y termina en su nodo, sin tramo '
        'recto sobre el edificio', () {
      final origen = data.lugar('lug_edificio_a')!;
      final destino = data.lugar('lug_cafeteria_ues')!;
      final ruta =
          motor.calcular(origen: origen, destino: destino, accesible: false);
      // Sin prepend del centro: el primer/último punto es un nodo del grafo.
      expect(ruta.aproxOrigen, 0);
      expect(ruta.puntos.first, equals(ruta.nodos.first.punto));
      expect(ruta.puntos.last, equals(ruta.nodos.last.punto));
    });
  });

  group('el grafo no atraviesa edificios', () {
    List<LatLng> anillo(Lugar l) => [
          for (final p in l.poligono!) LatLng(p.lat, p.lng),
        ];

    bool dentro(LatLng p, List<LatLng> poly) {
      var dentro = false;
      for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
        final a = poly[i], b = poly[j];
        if ((a.longitude > p.longitude) != (b.longitude > p.longitude) &&
            p.latitude <
                (b.latitude - a.latitude) *
                        (p.longitude - a.longitude) /
                        (b.longitude - a.longitude) +
                    a.latitude) {
          dentro = !dentro;
        }
      }
      return dentro;
    }

    double cruz(LatLng o, LatLng a, LatLng b) =>
        (a.latitude - o.latitude) * (b.longitude - o.longitude) -
        (a.longitude - o.longitude) * (b.latitude - o.latitude);

    bool segsCruzan(LatLng p1, LatLng p2, LatLng p3, LatLng p4) =>
        (cruz(p3, p4, p1) > 0) != (cruz(p3, p4, p2) > 0) &&
        (cruz(p1, p2, p3) > 0) != (cruz(p1, p2, p4) > 0);

    bool aristaCruza(LatLng a, LatLng b, List<LatLng> poly) {
      if (dentro(a, poly) || dentro(b, poly)) return true;
      for (var i = 0; i < poly.length; i++) {
        if (segsCruzan(a, b, poly[i], poly[(i + 1) % poly.length])) return true;
      }
      return false;
    }

    test('ninguna arista cruza el polígono de un edificio', () {
      final nodo = {for (final n in data.nodos) n.id: n.punto};
      final edificios = {
        for (final l in data.lugares)
          if (l.poligono != null && l.poligono!.length >= 3) l.id: anillo(l)
      };
      final infractoras = <String>[];
      for (final ar in data.aristas) {
        final a = nodo[ar.a]!, b = nodo[ar.b]!;
        for (final e in edificios.entries) {
          // la arista propia de un lugar sí toca su edificio (la entrada)
          if (ar.a == 'n_${e.key}' || ar.b == 'n_${e.key}') continue;
          if (aristaCruza(LatLng(a.lat, a.lng), LatLng(b.lat, b.lng), e.value)) {
            infractoras.add('${ar.a}↔${ar.b} sobre ${e.key}');
          }
        }
      }
      expect(infractoras, isEmpty, reason: infractoras.join('\n'));
    });

    test('todos los lugares quedan conectados al acceso principal', () {
      final ady = <String, Set<String>>{};
      for (final ar in data.aristas) {
        ady.putIfAbsent(ar.a, () => {}).add(ar.b);
        ady.putIfAbsent(ar.b, () => {}).add(ar.a);
      }
      final vistos = <String>{'n_lug_acceso_principal'};
      final cola = <String>['n_lug_acceso_principal'];
      while (cola.isNotEmpty) {
        for (final v in ady[cola.removeLast()] ?? const <String>{}) {
          if (vistos.add(v)) cola.add(v);
        }
      }
      for (final l in data.lugares) {
        expect(vistos.contains('n_${l.id}'), isTrue, reason: 'aislado: ${l.id}');
      }
    });
  });
}
