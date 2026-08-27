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

  test('el catálogo de prueba carga con contenido', () {
    expect(data.edificios, isNotEmpty);
    expect(data.espacios.length, greaterThan(15));
    expect(data.docentes, isNotEmpty);
    expect(data.nodos, isNotEmpty);
    expect(data.aristas, isNotEmpty);
  });

  test('todas las aristas referencian nodos existentes', () {
    final ids = {for (final n in data.nodos) n.id};
    for (final a in data.aristas) {
      expect(ids.contains(a.a), isTrue, reason: 'nodo ${a.a} no existe');
      expect(ids.contains(a.b), isTrue, reason: 'nodo ${a.b} no existe');
    }
  });

  test('las asignaciones apuntan a espacios reales', () {
    for (final d in data.docentes) {
      for (final asg in d.asignaciones) {
        expect(data.espacio(asg.espacioId), isNotNull,
            reason: '${d.nombre} → ${asg.espacioId}');
      }
    }
  });

  group('búsqueda universal', () {
    test('encuentra a un docente por apellido', () {
      final r = buscar(data, 'martinez');
      expect(r.first.tipo, TipoResultado.docente);
      expect(r.first.titulo, contains('Martínez'));
    });

    test('encuentra un aula por su número', () {
      final r = buscar(data, 'B-101');
      expect(r.any((x) => x.titulo == 'AULA B-101'), isTrue);
    });

    test('es insensible a acentos', () {
      expect(buscar(data, 'cafeteria'), isNotEmpty);
      expect(buscar(data, 'Cafetería'), isNotEmpty);
    });

    test('el id de cada resultado abre una ficha válida', () {
      for (final q in ['edificio', 'aula', 'biblioteca', 'martinez', 'bano']) {
        for (final r in buscar(data, q)) {
          switch (r.tipo) {
            case TipoResultado.docente:
              expect(data.docente(r.id), isNotNull, reason: '$q → ${r.id}');
            case TipoResultado.espacio:
            case TipoResultado.edificio:
              expect(data.espacio(r.id), isNotNull, reason: '$q → ${r.id}');
          }
        }
      }
    });
  });

  group('ruteo peatonal', () {
    final origen = 'esp_acceso';
    const destinoN1 = 'esp_aula_b101'; // Nivel 1 del Edificio B

    test('ruta normal al Nivel 1 usa escaleras', () {
      final r = motor.calcular(
        origen: data.espacio(origen)!,
        destino: data.espacio(destinoN1)!,
        accesible: false,
      );
      expect(r.sinRuta, isFalse);
      expect(r.usaEscaleras, isTrue);
      expect(r.puntos.length, greaterThan(2));
    });

    test('ruta accesible evita escaleras y usa elevador', () {
      final r = motor.calcular(
        origen: data.espacio(origen)!,
        destino: data.espacio(destinoN1)!,
        accesible: true,
      );
      expect(r.sinRuta, isFalse);
      expect(r.usaEscaleras, isFalse);
      expect(r.usaElevador || r.usaRampa, isTrue);
    });

    test('describir() produce pasos con inicio y fin', () {
      final r = motor.calcular(
        origen: data.espacio(origen)!,
        destino: data.espacio(destinoN1)!,
        accesible: true,
      );
      final pasos = motor.describir(
        r,
        origen: data.espacio(origen)!,
        destino: data.espacio(destinoN1)!,
      );
      expect(pasos.first.texto, contains('Sales de'));
      expect(pasos.last.texto, contains('Llegas a'));
      expect(pasos.length, greaterThan(2));
    });

    test('hay ruta entre cualquier par de espacios enganchados al grafo', () {
      final conNodo = data.espacios
          .where((e) => data.nodos.any((n) => n.espacioId == e.id))
          .toList();
      for (final a in conNodo) {
        for (final b in conNodo) {
          if (identical(a, b)) continue;
          final r = motor.calcular(origen: a, destino: b, accesible: false);
          expect(r.sinRuta, isFalse,
              reason: 'sin ruta ${a.id} → ${b.id}');
        }
      }
    });
  });
}
