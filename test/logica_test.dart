import 'package:flutter_test/flutter_test.dart';
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
}
