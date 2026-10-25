import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ues_rutas/core/brand.dart';
import 'package:ues_rutas/data/campus_repository.dart';
import 'package:ues_rutas/data/models.dart';
import 'package:ues_rutas/data/providers.dart';
import 'package:ues_rutas/data/routing.dart';
import 'package:ues_rutas/features/ajustes/settings_controller.dart';

/// Invariantes del catálogo generado desde el plano oficial
/// (`scripts/importar_plano.py`) y del grafo sobre sus andadores
/// (`scripts/generar_grafo.py`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CampusData data;
  late MotorRutas motor;

  setUpAll(() async {
    data = await const SeedCampusRepository().cargar();
    motor = MotorRutas(data);
  });

  group('catálogo del plano', () {
    test('cada clave del plano existe una sola vez', () {
      const claves = [
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N',
        'O', 'P', 'Q', 'R', 'S', 'S1', 'T', 'V', // edificios
        '1', '2', '3', '4', '6', '12', '13', // numerados
      ];
      for (final c in claves) {
        final n = data.lugares.where((l) => l.clave == c).length;
        expect(n, 1, reason: 'clave $c aparece $n veces');
      }
    });

    test('los ids que usan enlaces, docentes y rutas siguen existiendo', () {
      for (final id in [
        'lug_edificio_a',
        'lug_edificio_b',
        'lug_centro_de_computo',
        'lug_aula_magna_biblioteca',
        'lug_cafeteria_ues',
        'lug_gimnasio_ues',
        'lug_domo_ues',
        'lug_control_escolar_ues',
        'lug_acceso_principal',
        'lug_acceso_poniente',
        'lug_campo_deportivo',
      ]) {
        expect(data.lugar(id), isNotNull, reason: id);
      }
    });

    test('los ids retirados resuelven por alias al lugar que los absorbió', () {
      expect(data.lugar('lug_oficinas_academicas')?.id, 'lug_control_escolar_ues');
      expect(data.lugar('lug_edificio_de_musica')?.id, 'lug_edificio_r');
      expect(data.lugar('lug_plaza_central')?.id, 'lug_explanada_estudiantil');
      expect(data.lugar('id_inexistente'), isNull);
    });

    test('los edificios tienen polígono y las áreas transitables no bloquean',
        () {
      for (final l in data.lugares.where((l) => l.clave != null && l.clave != '12')) {
        expect(l.poligono, isNotNull, reason: l.id);
        expect(l.poligono!.length, greaterThanOrEqualTo(4), reason: l.id);
      }
      expect(data.lugar('lug_explanada_estudiantil')!.transitable, isTrue);
      expect(data.lugar('lug_estacionamiento_1')!.transitable, isTrue);
      expect(data.lugar('lug_edificio_a')!.transitable, isFalse);
      expect(data.info.campoDeportivo.length, greaterThanOrEqualTo(4));
    });

    test('las oficinas de los docentes apuntan a lugares reales', () {
      for (final d in data.docentes) {
        if (d.oficinaLugarId != null) {
          expect(data.lugar(d.oficinaLugarId), isNotNull, reason: d.nombre);
        }
      }
    });

    test('buscar "baños" o "sanitarios" da varios edificios', () {
      final banos = data.lugares
          .where((l) => l.descripcion.toLowerCase().contains('baños'))
          .length;
      expect(banos, greaterThanOrEqualTo(3));
    });

    test('el plano georreferenciado viene con sus tres esquinas', () {
      final p = data.info.planoOverlay;
      expect(p, isNotNull);
      expect(p!.imagen, startsWith('assets/plano/'));
      // Norte arriba: la esquina superior queda al norte de la inferior.
      expect(p.tl.lat, greaterThan(p.bl.lat));
      expect(p.br.lng, greaterThan(p.bl.lng));
    });

    test('categorías: los edificios ya no son "aula"', () {
      expect(data.lugares.any((l) => l.categoria == CategoriaMapa.aula), isFalse);
      expect(data.lugar('lug_laboratorios_centrales')!.categoria,
          CategoriaMapa.laboratorio);
    });
  });

  group('filtro de categorías del mapa', () {
    test('oculta, persiste entre sesiones y "Todos" limpia', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ProviderContainer contenedor() => ProviderContainer(
          overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);

      final c1 = contenedor();
      expect(c1.read(categoriasOcultasProvider), isEmpty);
      await c1.read(categoriasOcultasProvider.notifier)
          .alternar(CategoriaMapa.deportivo);
      await c1.read(categoriasOcultasProvider.notifier)
          .alternar(CategoriaMapa.estacionamiento);
      expect(c1.read(categoriasOcultasProvider),
          {CategoriaMapa.deportivo, CategoriaMapa.estacionamiento});
      c1.dispose();

      // Otra sesión: arranca con lo guardado.
      final c2 = contenedor();
      expect(c2.read(categoriasOcultasProvider),
          {CategoriaMapa.deportivo, CategoriaMapa.estacionamiento});
      await c2.read(categoriasOcultasProvider.notifier)
          .alternar(CategoriaMapa.deportivo);
      expect(c2.read(categoriasOcultasProvider), {CategoriaMapa.estacionamiento});
      await c2.read(categoriasOcultasProvider.notifier).mostrarTodas();
      expect(c2.read(categoriasOcultasProvider), isEmpty);
      expect(prefs.getStringList('mapa.categoriasOcultas'), isEmpty);
      c2.dispose();
    });
  });

  group('grafo sobre los andadores del plano', () {
    test('es denso y con tramos cortos', () {
      expect(data.nodos.length, greaterThanOrEqualTo(400));
      final ids = {for (final n in data.nodos) n.id: n};
      final pares = <String>{};
      var largas = 0;
      for (final a in data.aristas) {
        expect(pares.add('${a.a}|${a.b}'), isTrue, reason: 'arista repetida');
        final d = ids[a.a]!.punto.distanciaA(ids[a.b]!.punto);
        if (!a.a.startsWith('n_') && !a.b.startsWith('n_') && d > 14) largas++;
      }
      // Solo los tramos manuales (escalinata, cruce al gimnasio) pueden ser
      // largos; la malla y los corredores van en tramos cortos.
      expect(largas, lessThanOrEqualTo(8),
          reason: '$largas aristas de camino miden más de 14 m');
    });

    test('rutas de referencia existen y no dan un rodeo absurdo', () {
      // Pares por todo el campus, incluidos los que cruzan el núcleo (plaza
      // de N, explanada, corredor de F): si la malla se rompe en un pasaje
      // angosto la ruta da la vuelta a media manzana y esto lo delata.
      for (final (o, d) in [
        ('lug_edificio_a', 'lug_aula_magna_biblioteca'),
        ('lug_edificio_f', 'lug_ciencias_de_la_salud'),
        ('lug_acceso_principal', 'lug_gimnasio_ues'),
        ('lug_control_escolar_ues', 'lug_edificio_h'),
        ('lug_edificio_e', 'lug_centro_de_computo'),
        ('lug_edificio_a', 'lug_edificio_n'),
        ('lug_edificio_a', 'lug_gimnasio_ues'),
        ('lug_edificio_a', 'lug_edificio_h'),
        ('lug_explanada_estudiantil', 'lug_edificio_f'),
        ('lug_edificio_n', 'lug_edificio_c'),
        ('lug_edificio_b', 'lug_centro_de_computo'),
        ('lug_cafeteria_ues', 'lug_edificio_g'),
        ('lug_recursos_humanos', 'lug_edificio_a'),
      ]) {
        final origen = data.lugar(o)!, destino = data.lugar(d)!;
        final r = motor.calcular(
            origen: origen, destino: destino, accesible: false);
        expect(r.sinRuta, isFalse, reason: '$o → $d');
        final recta = origen.punto.distanciaA(destino.punto);
        expect(r.distancia, lessThan(recta * 2.2 + 40),
            reason: '$o → $d: ${r.distancia.round()} m por el grafo, '
                '${recta.round()} m en recta');
      }
    });

    test('la ruta accesible de F a H evita la escalinata', () {
      final r = motor.calcular(
        origen: data.lugar('lug_edificio_f')!,
        destino: data.lugar('lug_edificio_h')!,
        accesible: true,
      );
      expect(r.sinRuta, isFalse);
      expect(r.usaEscaleras, isFalse);
    });
  });
}
