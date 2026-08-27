import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/brand.dart';

/// Coordenada geográfica. Reemplaza el sistema local x/y anterior.
@immutable
class Punto {
  const Punto(this.lat, this.lng);

  final double lat;
  final double lng;

  LatLng toLatLng() => LatLng(lat, lng);

  factory Punto.fromJson(Map<String, dynamic> j) =>
      Punto((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble());

  /// Distancia en metros (haversine).
  double distanciaA(Punto o) {
    const r = 6371000.0;
    final p1 = lat * math.pi / 180;
    final p2 = o.lat * math.pi / 180;
    final dp = (o.lat - lat) * math.pi / 180;
    final dl = (o.lng - lng) * math.pi / 180;
    final a = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(a)));
  }
}

/// Cualquier punto de interés del campus: edificio, servicio, área, acceso.
@immutable
class Lugar {
  const Lugar({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.punto,
    required this.accesible,
    this.nombreCorto,
    this.descripcion = '',
    this.poligono,
  });

  final String id;
  final String nombre;
  final String? nombreCorto;
  final CategoriaMapa categoria;
  final Punto punto;
  final bool accesible;
  final String descripcion;

  /// Contorno del edificio (si aplica), para dibujar sobre el mapa.
  final List<Punto>? poligono;

  bool get esEdificio =>
      categoria == CategoriaMapa.aula ||
      categoria == CategoriaMapa.biblioteca ||
      categoria == CategoriaMapa.oficina;

  String get etiquetaCorta => nombreCorto ?? nombre;

  factory Lugar.fromJson(Map<String, dynamic> j) => Lugar(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        nombreCorto: j['nombreCorto'] as String?,
        categoria: CategoriaMapa.desdeId(j['categoria'] as String?),
        punto: Punto.fromJson(j['punto'] as Map<String, dynamic>),
        accesible: (j['accesible'] ?? true) as bool,
        descripcion: (j['descripcion'] ?? '') as String,
        poligono: (j['poligono'] as List?)
            ?.map((e) => Punto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

@immutable
class Asignacion {
  const Asignacion({
    required this.materia,
    required this.grupo,
    required this.lugarId,
    required this.dia,
    required this.horaInicio,
    required this.minInicio,
    required this.horaFin,
    required this.minFin,
  });

  final String materia;
  final String grupo;
  final String lugarId;

  /// 1 = Lunes ... 6 = Sábado.
  final int dia;
  final int horaInicio;
  final int minInicio;
  final int horaFin;
  final int minFin;

  String get horario {
    String hhmm(int h, int m) => '$h:${m.toString().padLeft(2, '0')}';
    return '${hhmm(horaInicio, minInicio)}–${hhmm(horaFin, minFin)}';
  }

  factory Asignacion.fromJson(Map<String, dynamic> j) => Asignacion(
        materia: j['materia'] as String,
        grupo: (j['grupo'] ?? '') as String,
        lugarId: j['lugarId'] as String,
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
    required this.asignaciones,
    this.oficinaLugarId,
    this.fotoUrl,
  });

  final String id;
  final String nombre;
  final String departamento;
  final String correo;
  final String? oficinaLugarId;
  final List<Asignacion> asignaciones;
  final String? fotoUrl;

  static const _titulos = {
    'dr',
    'dra',
    'mtro',
    'mtra',
    'lic',
    'ing',
    'c',
    'prof',
    'profa',
  };

  String get iniciales {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .where((p) => !_titulos.contains(p.replaceAll('.', '').toLowerCase()))
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
        oficinaLugarId: j['oficinaLugarId'] as String?,
        fotoUrl: j['fotoUrl'] as String?,
        asignaciones: ((j['asignaciones'] ?? []) as List)
            .map((e) => Asignacion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Contorno y centro del campus (de `assets/seed/campus.json`).
@immutable
class CampusInfo {
  const CampusInfo({
    required this.perimetro,
    required this.centro,
    required this.campoDeportivo,
  });

  final List<Punto> perimetro;
  final Punto centro;
  final List<Punto> campoDeportivo;

  factory CampusInfo.fromJson(Map<String, dynamic> j) => CampusInfo(
        perimetro: (j['perimetro'] as List)
            .map((e) => Punto.fromJson(e as Map<String, dynamic>))
            .toList(),
        centro: Punto.fromJson(j['centro'] as Map<String, dynamic>),
        campoDeportivo: ((j['campoDeportivo'] ?? []) as List)
            .map((e) => Punto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

@immutable
class CampusData {
  const CampusData({
    required this.info,
    required this.lugares,
    required this.docentes,
    required this.nodos,
    required this.aristas,
  });

  final CampusInfo info;
  final List<Lugar> lugares;
  final List<Docente> docentes;
  final List<NodoRuta> nodos;
  final List<AristaRuta> aristas;

  List<Lugar> get edificios => lugares.where((l) => l.esEdificio).toList();

  Lugar? lugar(String? id) =>
      id == null ? null : lugares.firstWhereOrNull((l) => l.id == id);
  Docente? docente(String? id) =>
      id == null ? null : docentes.firstWhereOrNull((d) => d.id == id);
}

// --- Grafo de ruteo peatonal ---

enum TipoArista { exterior, pasillo, escalera, rampa, elevador, puerta }

@immutable
class NodoRuta {
  const NodoRuta({required this.id, required this.punto, this.lugarId});

  final String id;
  final Punto punto;
  final String? lugarId;

  factory NodoRuta.fromJson(Map<String, dynamic> j) => NodoRuta(
        id: j['id'] as String,
        punto: Punto.fromJson(j['punto'] as Map<String, dynamic>),
        lugarId: j['lugarId'] as String?,
      );
}

@immutable
class AristaRuta {
  const AristaRuta({required this.a, required this.b, required this.tipo});

  final String a;
  final String b;
  final TipoArista tipo;

  /// Transitable en "ruta accesible" (excluye escaleras).
  bool get esAccesible => tipo != TipoArista.escalera;

  factory AristaRuta.fromJson(Map<String, dynamic> j) => AristaRuta(
        a: j['a'] as String,
        b: j['b'] as String,
        tipo: TipoArista.values.byName((j['tipo'] ?? 'exterior') as String),
      );
}
