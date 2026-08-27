import 'dart:convert';

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

    final info = CampusInfo.fromJson(jsonDecode(r[0]) as Map<String, dynamic>);
    final lugares = (jsonDecode(r[1]) as List)
        .map((e) => Lugar.fromJson(e as Map<String, dynamic>))
        .toList();
    final docentes = (jsonDecode(r[2]) as List)
        .map((e) => Docente.fromJson(e as Map<String, dynamic>))
        .toList();

    final grafo = jsonDecode(r[3]) as Map<String, dynamic>;
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
}
