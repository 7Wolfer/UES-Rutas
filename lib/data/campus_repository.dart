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
    final results = await Future.wait([
      rootBundle.loadString('assets/seed/edificios.json'),
      rootBundle.loadString('assets/seed/espacios.json'),
      rootBundle.loadString('assets/seed/docentes.json'),
      rootBundle.loadString('assets/seed/rutas.json'),
    ]);

    final edificios = (jsonDecode(results[0]) as List)
        .map((e) => Edificio.fromJson(e as Map<String, dynamic>))
        .toList();
    final espacios = (jsonDecode(results[1]) as List)
        .map((e) => Espacio.fromJson(e as Map<String, dynamic>))
        .toList();
    final docentes = (jsonDecode(results[2]) as List)
        .map((e) => Docente.fromJson(e as Map<String, dynamic>))
        .toList();

    final grafo = jsonDecode(results[3]) as Map<String, dynamic>;
    final nodos = (grafo['nodos'] as List)
        .map((e) => NodoRuta.fromJson(e as Map<String, dynamic>))
        .toList();
    final aristas = (grafo['aristas'] as List)
        .map((e) => AristaRuta.fromJson(e as Map<String, dynamic>))
        .toList();

    return CampusData(
      edificios: edificios,
      espacios: espacios,
      docentes: docentes,
      nodos: nodos,
      aristas: aristas,
    );
  }
}
