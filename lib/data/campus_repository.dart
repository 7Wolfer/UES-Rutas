import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

/// Fuente del catálogo del campus. Hoy: JSON local (`assets/seed/`).
/// Mañana: consultas a Supabase con la misma firma.
abstract interface class CampusRepository {
  Future<CampusData> cargar();
}

class SeedCampusRepository implements CampusRepository {
  const SeedCampusRepository();

  @override
  Future<CampusData> cargar() async {
    final r = await Future.wait([
      rootBundle.loadString('assets/seed/campus.json'),
      rootBundle.loadString('assets/seed/lugares.json'),
      rootBundle.loadString('assets/seed/docentes.json'),
      rootBundle.loadString('assets/seed/rutas.json'),
    ]);
    final crudos = CampusCrudo(
      campus: r[0],
      lugares: r[1],
      docentes: r[2],
      rutas: r[3],
    );
    // El grafo (~380 KB) se decodifica en otro isolate para no trabar el
    // primer frame. En web no hay isolates reales: se hace en línea.
    return kIsWeb ? parsearCampus(crudos) : compute(parsearCampus, crudos);
  }
}

/// Textos JSON del campus tal como vienen de los assets (o de la red).
@immutable
class CampusCrudo {
  const CampusCrudo({
    required this.campus,
    required this.lugares,
    required this.docentes,
    required this.rutas,
  });

  final String campus;
  final String lugares;
  final String docentes;
  final String rutas;
}

/// Convierte los JSON del campus en modelos. Es una función de nivel superior
/// para poder correrla con `compute`.
CampusData parsearCampus(CampusCrudo c) {
  final info = CampusInfo.fromJson(jsonDecode(c.campus) as Map<String, dynamic>);
  final lugares = (jsonDecode(c.lugares) as List)
      .map((e) => Lugar.fromJson(e as Map<String, dynamic>))
      .toList();
  final docentes = (jsonDecode(c.docentes) as List)
      .map((e) => Docente.fromJson(e as Map<String, dynamic>))
      .toList();

  final grafo = jsonDecode(c.rutas) as Map<String, dynamic>;
  final nodos = (grafo['nodos'] as List)
      .map((e) => NodoRuta.fromJson(e as Map<String, dynamic>))
      .toList();
  final aristas = (grafo['aristas'] as List)
      .map((e) => AristaRuta.fromJson(e as Map<String, dynamic>))
      .toList();

  return CampusData(
    info: info,
    lugares: lugares,
    docentes: docentes,
    nodos: nodos,
    aristas: aristas,
  );
}
