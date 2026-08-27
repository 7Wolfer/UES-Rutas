import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'busqueda.dart';
import 'campus_repository.dart';
import 'models.dart';
import 'routing.dart';

final campusRepositoryProvider = Provider<CampusRepository>(
  (ref) => const SeedCampusRepository(),
);

final campusDataProvider = FutureProvider<CampusData>(
  (ref) => ref.watch(campusRepositoryProvider).cargar(),
);

/// Motor de ruteo listo cuando el catálogo terminó de cargar.
final motorRutasProvider = Provider<MotorRutas?>((ref) {
  final data = ref.watch(campusDataProvider).valueOrNull;
  return data == null ? null : MotorRutas(data);
});

/// Texto actual del buscador universal.
final consultaBusquedaProvider = StateProvider<String>((ref) => '');

/// Resultados derivados de la consulta + el catálogo.
final resultadosBusquedaProvider = Provider<List<ResultadoBusqueda>>((ref) {
  final data = ref.watch(campusDataProvider).valueOrNull;
  final q = ref.watch(consultaBusquedaProvider);
  if (data == null) return const [];
  return buscar(data, q);
});
