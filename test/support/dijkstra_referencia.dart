import 'package:collection/collection.dart';
import 'package:ues_rutas/data/models.dart';
import 'package:ues_rutas/data/routing.dart';

/// Dijkstra "de libro" (una fuente, todos los destinos) sobre los ids del
/// grafo, con las mismas penalizaciones que el motor. Sirve de referencia para
/// comprobar que el A* optimizado devuelve exactamente el mismo costo.
Map<String, double> costosDijkstra(
  CampusData data,
  String desde, {
  required bool accesible,
}) {
  final punto = {for (final n in data.nodos) n.id: n.punto};
  final ady = <String, List<(String, double)>>{};
  for (final a in data.aristas) {
    final pen = MotorRutas.penalizacion(a.tipo, accesible: accesible);
    if (pen == double.infinity) continue;
    final c = punto[a.a]!.distanciaA(punto[a.b]!) + pen;
    ady.putIfAbsent(a.a, () => []).add((a.b, c));
    ady.putIfAbsent(a.b, () => []).add((a.a, c));
  }
  final dist = <String, double>{desde: 0};
  final hechos = <String>{};
  final cola = PriorityQueue<(String, double)>((x, y) => x.$2.compareTo(y.$2))
    ..add((desde, 0));
  while (cola.isNotEmpty) {
    final (u, d) = cola.removeFirst();
    if (!hechos.add(u)) continue;
    for (final (v, c) in ady[u] ?? const <(String, double)>[]) {
      final nd = d + c;
      if (nd < (dist[v] ?? double.infinity)) {
        dist[v] = nd;
        cola.add((v, nd));
      }
    }
  }
  return dist;
}
