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
    this.clave,
    this.transitable = false,
  });

  /// Id del origen sintético "mi ubicación" (no existe en el catálogo).
  static const String idMiUbicacion = '__mi_ubicacion';

  /// Origen efímero para trazar una ruta desde la posición del usuario.
  factory Lugar.miUbicacion(LatLng pos) => Lugar(
        id: idMiUbicacion,
        nombre: 'Mi ubicación',
        categoria: CategoriaMapa.servicios,
        punto: Punto(pos.latitude, pos.longitude),
        accesible: true,
      );

  final String id;
  final String nombre;
  final String? nombreCorto;
  final CategoriaMapa categoria;
  final Punto punto;
  final bool accesible;
  final String descripcion;

  /// Contorno del edificio (si aplica), para dibujar sobre el mapa.
  final List<Punto>? poligono;

  /// Letra o número con que el plano oficial identifica el lugar ("A", "S1",
  /// "6"). Es lo que ve la gente en la señalética del campus.
  final String? clave;

  /// `true` si el polígono es un área por la que se camina (explanada,
  /// estacionamiento): se dibuja, pero no estorba a las rutas.
  final bool transitable;

  bool get esEdificio =>
      categoria == CategoriaMapa.aula ||
      categoria == CategoriaMapa.edificio ||
      categoria == CategoriaMapa.laboratorio ||
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
        clave: j['clave'] as String?,
        transitable: (j['transitable'] ?? false) as bool,
      );
}

/// Ids retirados del catálogo al adoptar la nomenclatura del plano oficial.
/// Siguen resolviendo (enlaces compartidos, datos antiguos) al lugar que los
/// absorbió.
const aliasesLugar = <String, String>{
  'lug_oficinas_academicas': 'lug_control_escolar_ues',
  'lug_edificio_de_musica': 'lug_edificio_r',
  'lug_plaza_central': 'lug_explanada_estudiantil',
  'lug_sanitarios_zona_explanada': 'lug_edificio_d',
  'lug_sanitarios_zona_edificio_g': 'lug_edificio_g',
  'lug_sanitarios_zona_laboratorios': 'lug_laboratorios_centrales',
};

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

/// El plano oficial georreferenciado, para la vista "Plano" del mapa: imagen
/// (asset) y sus tres esquinas en coordenadas, tal como las produce
/// `scripts/importar_plano.py`.
@immutable
class PlanoOverlay {
  const PlanoOverlay({
    required this.imagen,
    required this.tl,
    required this.bl,
    required this.br,
  });

  final String imagen;
  final Punto tl;
  final Punto bl;
  final Punto br;

  factory PlanoOverlay.fromJson(Map<String, dynamic> j) {
    final e = j['esquinas'] as Map<String, dynamic>;
    return PlanoOverlay(
      imagen: j['imagen'] as String,
      tl: Punto.fromJson(e['tl'] as Map<String, dynamic>),
      bl: Punto.fromJson(e['bl'] as Map<String, dynamic>),
      br: Punto.fromJson(e['br'] as Map<String, dynamic>),
    );
  }
}

/// Contorno y centro del campus (de `assets/seed/campus.json`).
@immutable
class CampusInfo {
  const CampusInfo({
    required this.perimetro,
    required this.centro,
    required this.campoDeportivo,
    this.planoOverlay,
  });

  final List<Punto> perimetro;
  final Punto centro;
  final List<Punto> campoDeportivo;
  final PlanoOverlay? planoOverlay;

  factory CampusInfo.fromJson(Map<String, dynamic> j) => CampusInfo(
        perimetro: (j['perimetro'] as List)
            .map((e) => Punto.fromJson(e as Map<String, dynamic>))
            .toList(),
        centro: Punto.fromJson(j['centro'] as Map<String, dynamic>),
        campoDeportivo: ((j['campoDeportivo'] ?? []) as List)
            .map((e) => Punto.fromJson(e as Map<String, dynamic>))
            .toList(),
        planoOverlay: j['planoOverlay'] == null
            ? null
            : PlanoOverlay.fromJson(j['planoOverlay'] as Map<String, dynamic>),
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

  /// Busca por id; los ids retirados (`aliasesLugar`) resuelven al lugar que
  /// los absorbió, para que los enlaces antiguos sigan abriendo.
  Lugar? lugar(String? id) {
    if (id == null) return null;
    final real = aliasesLugar[id] ?? id;
    return lugares.firstWhereOrNull((l) => l.id == real);
  }
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
