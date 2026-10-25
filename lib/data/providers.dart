import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../core/brand.dart';
import '../features/ajustes/settings_controller.dart';
import '../services/ubicacion_service.dart';
import 'avisos.dart';
import 'busqueda.dart';
import 'calendario.dart';
import 'campus_repository.dart';
import 'models.dart';
import 'routing.dart';

// --- Catálogo del campus ---

final campusRepositoryProvider = Provider<CampusRepository>(
  (ref) => const SeedCampusRepository(),
);

final campusDataProvider = FutureProvider<CampusData>(
  (ref) => ref.watch(campusRepositoryProvider).cargar(),
);

final motorRutasProvider = Provider<MotorRutas?>((ref) {
  final data = ref.watch(campusDataProvider).valueOrNull;
  return data == null ? null : MotorRutas(data);
});

// --- Ubicación del usuario ---

final ubicacionServiceProvider =
    Provider<UbicacionService>((ref) => UbicacionService.instance);

/// Última posición conocida del usuario (`null` hasta que se localiza una vez).
class PosicionUsuarioNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  /// Pide la ubicación (puede disparar el diálogo del sistema) y la guarda si
  /// tuvo éxito. Devuelve el resultado completo para que la UI muestre errores.
  Future<UbicacionResultado> localizar() async {
    final r = await ref.read(ubicacionServiceProvider).localizar();
    if (r.exito) state = r.posicion;
    return r;
  }
}

final posicionUsuarioProvider =
    NotifierProvider<PosicionUsuarioNotifier, LatLng?>(
        PosicionUsuarioNotifier.new);

// --- Teselas del mapa offline ---

/// Claves "z_x_y" de las teselas del campus incluidas como assets para uso
/// offline. Se sobreescribe en `main.dart` tras leer
/// `assets/tiles/manifest.json`; el valor por defecto (vacío) hace que todo vaya
/// a la red, como antes.
final teselasBundledProvider = Provider<Set<String>>((ref) => const {});

// --- Búsqueda ---

final consultaBusquedaProvider = StateProvider<String>((ref) => '');

final resultadosBusquedaProvider = Provider<List<ResultadoBusqueda>>((ref) {
  final data = ref.watch(campusDataProvider).valueOrNull;
  final q = ref.watch(consultaBusquedaProvider);
  if (data == null) return const [];
  return buscar(data, q);
});

/// Orden en que se presentan las categorías (directorio, filtro del mapa).
const ordenCategorias = [
  CategoriaMapa.edificio,
  CategoriaMapa.laboratorio,
  CategoriaMapa.biblioteca,
  CategoriaMapa.oficina,
  CategoriaMapa.alimentos,
  CategoriaMapa.deportivo,
  CategoriaMapa.servicios,
  CategoriaMapa.estacionamiento,
  CategoriaMapa.aula,
];

/// Directorio pre-agrupado para la hoja de inicio: intercala encabezados de
/// categoría (`CategoriaMapa`) y `Lugar`. Memorizado para no reagrupar/ordenar
/// en cada build de la hoja.
final directorioProvider = Provider<List<Object>>((ref) {
  final data = ref.watch(campusDataProvider).valueOrNull;
  if (data == null) return const [];
  final porCat = <CategoriaMapa, List<Lugar>>{};
  for (final l in data.lugares) {
    porCat.putIfAbsent(l.categoria, () => []).add(l);
  }
  final items = <Object>[];
  for (final cat in ordenCategorias) {
    final lugares = porCat[cat];
    if (lugares == null) continue;
    lugares.sort((a, b) => a.nombre.compareTo(b.nombre));
    items
      ..add(cat)
      ..addAll(lugares);
  }
  return items;
});

/// Lugar seleccionado en el mapa / hoja de inicio (`null` = ninguno).
final lugarSeleccionadoProvider = StateProvider<String?>((ref) => null);

// --- Estilo del mapa ---

/// `plano` = el plano oficial georreferenciado sobre el mapa estándar.
enum EstiloMapa { estandar, satelite, plano }

final estiloMapaProvider =
    StateProvider<EstiloMapa>((ref) => EstiloMapa.estandar);

// --- Filtro de pines por categoría ---

/// Categorías que el usuario decidió ocultar en el mapa (persistido). Se guarda
/// lo oculto, no lo visible: así todo se ve por defecto y una categoría nueva
/// aparece sola. No afecta al directorio ni a la búsqueda.
class CategoriasOcultasController extends Notifier<Set<CategoriaMapa>> {
  static const _k = 'mapa.categoriasOcultas';

  @override
  Set<CategoriaMapa> build() {
    final guardadas = ref.read(sharedPrefsProvider).getStringList(_k) ?? const [];
    return {
      for (final n in guardadas)
        for (final c in CategoriaMapa.values)
          if (c.name == n) c,
    };
  }

  Future<void> alternar(CategoriaMapa c) async {
    state = state.contains(c) ? ({...state}..remove(c)) : {...state, c};
    await _guardar();
  }

  Future<void> mostrarTodas() async {
    state = const {};
    await _guardar();
  }

  Future<void> _guardar() => ref
      .read(sharedPrefsProvider)
      .setStringList(_k, [for (final c in state) c.name]);
}

final categoriasOcultasProvider =
    NotifierProvider<CategoriasOcultasController, Set<CategoriaMapa>>(
        CategoriasOcultasController.new);

// --- Avisos / notificaciones ---

final avisosProvider = FutureProvider<List<Aviso>>((ref) => cargarAvisos());

/// Ids de avisos leídos (persistido).
class AvisosLeidosController extends Notifier<Set<String>> {
  static const _k = 'avisos.leidos';

  @override
  Set<String> build() =>
      ref.read(sharedPrefsProvider).getStringList(_k)?.toSet() ?? <String>{};

  Future<void> marcarLeido(String id) async {
    state = {...state, id};
    await ref.read(sharedPrefsProvider).setStringList(_k, state.toList());
  }

  Future<void> marcarTodos(Iterable<String> ids) async {
    state = {...state, ...ids};
    await ref.read(sharedPrefsProvider).setStringList(_k, state.toList());
  }
}

final avisosLeidosProvider =
    NotifierProvider<AvisosLeidosController, Set<String>>(
        AvisosLeidosController.new);

final avisosNoLeidosProvider = Provider<int>((ref) {
  final avisos = ref.watch(avisosProvider).valueOrNull ?? const [];
  final leidos = ref.watch(avisosLeidosProvider);
  return avisos.where((a) => !leidos.contains(a.id)).length;
});

/// Aviso a mostrar como banner en el inicio (`null` si ya se descartó).
final bannerDescartadoProvider = StateProvider<String?>((ref) => null);

final avisoDestacadoProvider = Provider<Aviso?>((ref) {
  final avisos = ref.watch(avisosProvider).valueOrNull ?? const [];
  final descartado = ref.watch(bannerDescartadoProvider);
  final leidos = ref.watch(avisosLeidosProvider);
  for (final a in avisos) {
    if (a.id == descartado) continue;
    if (leidos.contains(a.id)) continue;
    if (a.categoria == CategoriaAviso.importante ||
        a.categoria == CategoriaAviso.ruta) {
      return a;
    }
  }
  return null;
});

// --- Calendario académico ---

final calendarioProvider =
    FutureProvider<CalendarioUes>((ref) => cargarCalendario());
