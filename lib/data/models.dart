import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../core/brand.dart';
import '../core/formato.dart';

/// Punto en el sistema de coordenadas del mapa ilustrativo (0..1000 x, 0..700 y).
/// Cuando se carguen planos reales, esto se reemplaza por lat/lng.
@immutable
class Punto {
  const Punto(this.x, this.y);

  final double x;
  final double y;

  factory Punto.fromJson(Map<String, dynamic> j) =>
      Punto((j['x'] as num).toDouble(), (j['y'] as num).toDouble());

  double distanciaA(Punto o) {
    final dx = x - o.x;
    final dy = y - o.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}

enum TipoEspacio { aula, oficina, servicio, edificio, exterior }

@immutable
class Edificio {
  const Edificio({
    required this.id,
    required this.clave,
    required this.nombre,
    required this.descripcion,
    required this.rect,
    required this.niveles,
  });

  final String id;

  /// Letra o clave corta ("E", "A"). Se muestra como "EDIFICIO E".
  final String clave;
  final String nombre;
  final String descripcion;

  /// Rectángulo [left, top, width, height] en coordenadas del mapa.
  final List<double> rect;

  /// Números de nivel disponibles, p. ej. [0, 1, 2].
  final List<int> niveles;

  String get etiqueta => etiquetaEdificio(clave);

  Punto get centro => Punto(rect[0] + rect[2] / 2, rect[1] + rect[3] / 2);

  factory Edificio.fromJson(Map<String, dynamic> j) => Edificio(
        id: j['id'] as String,
        clave: j['clave'] as String,
        nombre: j['nombre'] as String,
        descripcion: (j['descripcion'] ?? '') as String,
        rect: (j['rect'] as List).map((e) => (e as num).toDouble()).toList(),
        niveles: (j['niveles'] as List).map((e) => e as int).toList(),
      );
}

@immutable
class Espacio {
  const Espacio({
    required this.id,
    required this.tipo,
    required this.nombre,
    required this.edificioId,
    required this.nivel,
    required this.punto,
    required this.categoria,
    required this.accesible,
    this.numeroAula,
    this.descripcion = '',
  });

  final String id;
  final TipoEspacio tipo;
  final String nombre;

  /// `null` si el espacio es exterior (kiosko, plaza, estacionamiento abierto).
  final String? edificioId;
  final int nivel;
  final Punto punto;
  final CategoriaMapa categoria;
  final bool accesible;

  /// Número de aula ("1", "204") — solo para [TipoEspacio.aula].
  final String? numeroAula;
  final String descripcion;

  /// Texto para mostrar como título de la ficha.
  String get titulo {
    if (tipo == TipoEspacio.aula && numeroAula != null) {
      return etiquetaAula(numeroAula!);
    }
    return nombre;
  }

  factory Espacio.fromJson(Map<String, dynamic> j) => Espacio(
        id: j['id'] as String,
        tipo: TipoEspacio.values.byName(j['tipo'] as String),
        nombre: j['nombre'] as String,
        edificioId: j['edificioId'] as String?,
        nivel: (j['nivel'] ?? 0) as int,
        punto: Punto.fromJson(j['punto'] as Map<String, dynamic>),
        categoria: CategoriaMapa.desdeId(j['categoria'] as String?),
        accesible: (j['accesible'] ?? false) as bool,
        numeroAula: j['numeroAula'] as String?,
        descripcion: (j['descripcion'] ?? '') as String,
      );
}

@immutable
class Asignacion {
  const Asignacion({
    required this.materia,
    required this.grupo,
    required this.espacioId,
    required this.dia,
    required this.horaInicio,
    required this.minInicio,
    required this.horaFin,
    required this.minFin,
  });

  final String materia;
  final String grupo;
  final String espacioId;

  /// 1 = Lunes ... 6 = Sábado.
  final int dia;
  final int horaInicio;
  final int minInicio;
  final int horaFin;
  final int minFin;

  String get diaNombre => diasSemana[(dia - 1).clamp(0, diasSemana.length - 1)];
  String get horario =>
      rangoHorario(horaInicio, minInicio, horaFin, minFin);

  factory Asignacion.fromJson(Map<String, dynamic> j) => Asignacion(
        materia: j['materia'] as String,
        grupo: (j['grupo'] ?? '') as String,
        espacioId: j['espacioId'] as String,
        dia: j['dia'] as int,
        horaInicio: j['horaInicio'] as int,
        minInicio: (j['minInicio'] ?? 0) as int,
        horaFin: j['horaFin'] as int,
        minFin: (j['minFin'] ?? 0) as int,
      );
}

@immutable
class Docente {
  const Docente({
    required this.id,
    required this.nombre,
    required this.departamento,
    required this.correo,
    required this.oficinaEspacioId,
    required this.asignaciones,
    this.fotoUrl,
  });

  final String id;
  final String nombre;
  final String departamento;
  final String correo;
  final String? oficinaEspacioId;
  final List<Asignacion> asignaciones;
  final String? fotoUrl;

  static const _titulos = {
    'dr', 'dra', 'mtro', 'mtra', 'lic', 'ing', 'c', 'prof', 'profa',
  };

  String get iniciales {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .where((p) => !_titulos.contains(
              p.replaceAll('.', '').toLowerCase(),
            ))
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first.substring(0, 1) + partes[1].substring(0, 1))
        .toUpperCase();
  }

  factory Docente.fromJson(Map<String, dynamic> j) => Docente(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        departamento: (j['departamento'] ?? '') as String,
        correo: (j['correo'] ?? '') as String,
        oficinaEspacioId: j['oficinaEspacioId'] as String?,
        fotoUrl: j['fotoUrl'] as String?,
        asignaciones: ((j['asignaciones'] ?? []) as List)
            .map((e) => Asignacion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Contenedor de todo el catálogo del campus (seed local o Supabase).
@immutable
class CampusData {
  const CampusData({
    required this.edificios,
    required this.espacios,
    required this.docentes,
    required this.nodos,
    required this.aristas,
  });

  final List<Edificio> edificios;
  final List<Espacio> espacios;
  final List<Docente> docentes;
  final List<NodoRuta> nodos;
  final List<AristaRuta> aristas;

  Edificio? edificio(String? id) =>
      id == null ? null : edificios.where((e) => e.id == id).firstOrNull;
  Espacio? espacio(String? id) =>
      id == null ? null : espacios.where((e) => e.id == id).firstOrNull;
  Docente? docente(String? id) =>
      id == null ? null : docentes.where((e) => e.id == id).firstOrNull;
}

// --- Grafo de ruteo peatonal ---

enum TipoArista { exterior, pasillo, escalera, rampa, elevador, puerta }

@immutable
class NodoRuta {
  const NodoRuta({
    required this.id,
    required this.punto,
    required this.nivel,
    this.espacioId,
  });

  final String id;
  final Punto punto;
  final int nivel;

  /// Si el nodo coincide con un espacio (entrada, aula), su id.
  final String? espacioId;

  factory NodoRuta.fromJson(Map<String, dynamic> j) => NodoRuta(
        id: j['id'] as String,
        punto: Punto.fromJson(j['punto'] as Map<String, dynamic>),
        nivel: (j['nivel'] ?? 0) as int,
        espacioId: j['espacioId'] as String?,
      );
}

@immutable
class AristaRuta {
  const AristaRuta({
    required this.a,
    required this.b,
    required this.tipo,
  });

  final String a;
  final String b;
  final TipoArista tipo;

  /// ¿La arista es transitable en "ruta accesible"? Excluye escaleras.
  bool get esAccesible => tipo != TipoArista.escalera;

  factory AristaRuta.fromJson(Map<String, dynamic> j) => AristaRuta(
        a: j['a'] as String,
        b: j['b'] as String,
        tipo: TipoArista.values.byName((j['tipo'] ?? 'pasillo') as String),
      );
}
