import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/ajustes/settings_controller.dart';
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

// --- Búsqueda ---

final consultaBusquedaProvider = StateProvider<String>((ref) => '');

final resultadosBusquedaProvider = Provider<List<ResultadoBusqueda>>((ref) {
  final data = ref.watch(campusDataProvider).valueOrNull;
  final q = ref.watch(consultaBusquedaProvider);
  if (data == null) return const [];
  return buscar(data, q);
});

/// Lugar seleccionado en el mapa / hoja de inicio (`null` = ninguno).
final lugarSeleccionadoProvider = StateProvider<String?>((ref) => null);

// --- Estilo del mapa ---

enum EstiloMapa { estandar, satelite }

final estiloMapaProvider =
    StateProvider<EstiloMapa>((ref) => EstiloMapa.estandar);

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
