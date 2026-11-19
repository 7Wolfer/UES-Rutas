import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'models.dart';

/// Geometría plana del campus.
///
/// El campus mide menos de 1 km, así que una proyección equirectangular local
/// (metros al este/norte de un origen) basta: el error frente a haversine es
/// menor a 0.2 % y permite usar geometría euclidiana simple (proyecciones,
/// rumbos, polígonos) con números en metros.

/// Radio terrestre que usa `Punto.distanciaA`, para que ambas medidas cuadren.
const double radioTierraM = 6371000.0;

/// Punto en metros: `x` hacia el este, `y` hacia el norte.
@immutable
class PuntoXY {
  const PuntoXY(this.x, this.y);

  final double x;
  final double y;

  PuntoXY operator +(PuntoXY o) => PuntoXY(x + o.x, y + o.y);
  PuntoXY operator -(PuntoXY o) => PuntoXY(x - o.x, y - o.y);
  PuntoXY operator *(double k) => PuntoXY(x * k, y * k);

  double get norma => math.sqrt(x * x + y * y);
  double distanciaA(PuntoXY o) {
    final dx = o.x - x, dy = o.y - y;
    return math.sqrt(dx * dx + dy * dy);
  }

  double punto(PuntoXY o) => x * o.x + y * o.y;

  /// Componente z del producto cruz. Positivo = `o` queda a la izquierda.
  double cruz(PuntoXY o) => x * o.y - y * o.x;

  @override
  bool operator ==(Object other) =>
      other is PuntoXY && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() =>
      'PuntoXY(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

/// Proyección local alrededor de un origen (normalmente el centro del campus).
@immutable
class GeoLocal {
  GeoLocal(this.origen)
      : _kx = math.cos(origen.lat * math.pi / 180) * radioTierraM * math.pi / 180,
        _ky = radioTierraM * math.pi / 180;

  final Punto origen;
  final double _kx;
  final double _ky;

  PuntoXY aXY(Punto p) =>
      PuntoXY((p.lng - origen.lng) * _kx, (p.lat - origen.lat) * _ky);

  PuntoXY latLngAXY(double lat, double lng) =>
      PuntoXY((lng - origen.lng) * _kx, (lat - origen.lat) * _ky);

  Punto aPunto(PuntoXY p) => Punto(origen.lat + p.y / _ky, origen.lng + p.x / _kx);
}

/// Rumbo de `a` hacia `b` en grados, desde el norte y en sentido horario
/// (0 = norte, 90 = este), en [0, 360).
double rumbo(PuntoXY a, PuntoXY b) {
  final g = math.atan2(b.x - a.x, b.y - a.y) * 180 / math.pi;
  return g < 0 ? g + 360 : g;
}

/// Diferencia angular `hacia - desde` normalizada a (-180, 180].
/// Positiva = giro a la derecha (horario).
double difAngular(double hacia, double desde) {
  var d = (hacia - desde) % 360;
  if (d > 180) d -= 360;
  if (d <= -180) d += 360;
  return d;
}

/// Resultado de proyectar un punto sobre un segmento.
@immutable
class Proyeccion {
  const Proyeccion(this.punto, this.t, this.distancia);

  /// Punto más cercano sobre el segmento.
  final PuntoXY punto;

  /// Posición relativa en el segmento, en [0, 1].
  final double t;

  /// Distancia del punto original al segmento.
  final double distancia;
}

/// Proyecta `p` sobre el segmento `a`–`b` (acotado a sus extremos).
Proyeccion proyectarEnSegmento(PuntoXY p, PuntoXY a, PuntoXY b) {
  final abx = b.x - a.x, aby = b.y - a.y;
  final l2 = abx * abx + aby * aby;
  var t = l2 == 0 ? 0.0 : ((p.x - a.x) * abx + (p.y - a.y) * aby) / l2;
  if (t < 0) t = 0;
  if (t > 1) t = 1;
  final q = PuntoXY(a.x + abx * t, a.y + aby * t);
  return Proyeccion(q, t, p.distanciaA(q));
}

/// Distancias acumuladas a lo largo de una polilínea (mismo largo que `pts`).
Float64List acumulados(List<PuntoXY> pts) {
  final out = Float64List(pts.length);
  for (var i = 1; i < pts.length; i++) {
    out[i] = out[i - 1] + pts[i - 1].distanciaA(pts[i]);
  }
  return out;
}

/// Punto a `s` metros del inicio de la polilínea (`acum` = [acumulados]).
PuntoXY puntoEnDistancia(List<PuntoXY> pts, List<double> acum, double s) {
  if (pts.isEmpty) return const PuntoXY(0, 0);
  if (s <= 0) return pts.first;
  if (s >= acum.last) return pts.last;
  var lo = 0, hi = acum.length - 1;
  while (hi - lo > 1) {
    final mid = (lo + hi) >> 1;
    if (acum[mid] <= s) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final largo = acum[hi] - acum[lo];
  final t = largo == 0 ? 0.0 : (s - acum[lo]) / largo;
  final a = pts[lo], b = pts[hi];
  return PuntoXY(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
}

/// Simplificación de Douglas–Peucker que conserva siempre los índices de
/// `anclas` (cambios de tipo de tramo, extremos). Devuelve los índices
/// conservados, ordenados.
List<int> douglasPeucker(
  List<PuntoXY> pts,
  double tolerancia, {
  Set<int> anclas = const {},
}) {
  final n = pts.length;
  if (n <= 2) return [for (var i = 0; i < n; i++) i];
  final guardar = List<bool>.filled(n, false);
  final cortes = <int>{0, n - 1, ...anclas.where((i) => i > 0 && i < n - 1)}
      .toList()
    ..sort();
  for (final c in cortes) {
    guardar[c] = true;
  }
  void tramo(int i, int j) {
    if (j <= i + 1) return;
    var maxD = -1.0;
    var maxK = -1;
    for (var k = i + 1; k < j; k++) {
      final d = proyectarEnSegmento(pts[k], pts[i], pts[j]).distancia;
      if (d > maxD) {
        maxD = d;
        maxK = k;
      }
    }
    if (maxD > tolerancia) {
      guardar[maxK] = true;
      tramo(i, maxK);
      tramo(maxK, j);
    }
  }

  for (var c = 0; c < cortes.length - 1; c++) {
    tramo(cortes[c], cortes[c + 1]);
  }
  return [for (var i = 0; i < n; i++) if (guardar[i]) i];
}

/// ¿`p` está dentro del polígono? (regla par-impar; el anillo puede venir
/// abierto o cerrado).
bool puntoEnPoligono(PuntoXY p, List<PuntoXY> poli) {
  var dentro = false;
  for (var i = 0, j = poli.length - 1; i < poli.length; j = i++) {
    final a = poli[i], b = poli[j];
    if ((a.y > p.y) != (b.y > p.y) &&
        p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
      dentro = !dentro;
    }
  }
  return dentro;
}

/// Distancia de `p` al borde del polígono (0 si está dentro).
double distanciaAPoligono(PuntoXY p, List<PuntoXY> poli) {
  if (poli.isEmpty) return double.infinity;
  if (puntoEnPoligono(p, poli)) return 0;
  var min = double.infinity;
  for (var i = 0; i < poli.length; i++) {
    final d = proyectarEnSegmento(p, poli[i], poli[(i + 1) % poli.length])
        .distancia;
    if (d < min) min = d;
  }
  return min;
}

/// Centroide (promedio de vértices; suficiente para polígonos de edificios).
PuntoXY centroide(List<PuntoXY> poli) {
  var x = 0.0, y = 0.0;
  for (final p in poli) {
    x += p.x;
    y += p.y;
  }
  return poli.isEmpty ? const PuntoXY(0, 0) : PuntoXY(x / poli.length, y / poli.length);
}

/// ¿Se cruzan (propiamente) los segmentos p1–p2 y p3–p4?
bool segmentosCruzan(PuntoXY p1, PuntoXY p2, PuntoXY p3, PuntoXY p4) {
  double o(PuntoXY a, PuntoXY b, PuntoXY c) =>
      (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
  final d1 = o(p3, p4, p1), d2 = o(p3, p4, p2);
  final d3 = o(p1, p2, p3), d4 = o(p1, p2, p4);
  return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0));
}

/// ¿El segmento a–b entra en el polígono (cruza su borde o tiene un extremo
/// dentro)?
bool segmentoTocaPoligono(PuntoXY a, PuntoXY b, List<PuntoXY> poli) {
  if (puntoEnPoligono(a, poli) || puntoEnPoligono(b, poli)) return true;
  for (var i = 0; i < poli.length; i++) {
    if (segmentosCruzan(a, b, poli[i], poli[(i + 1) % poli.length])) {
      return true;
    }
  }
  return false;
}

/// Suavizado de un rumbo (en grados) con un filtro de paso bajo sobre el
/// vector unitario: evita el salto 359° → 0°.
class RumboSuavizado {
  RumboSuavizado({this.tau = 0.3});

  /// Constante de tiempo en segundos.
  final double tau;

  double? _x;
  double? _y;
  DateTime? _t;

  double? get valor {
    final x = _x, y = _y;
    if (x == null || y == null) return null;
    final g = math.atan2(x, y) * 180 / math.pi;
    return g < 0 ? g + 360 : g;
  }

  double? agregar(double grados, DateTime t) {
    final rad = grados * math.pi / 180;
    final nx = math.sin(rad), ny = math.cos(rad);
    final ultimo = _t;
    if (_x == null || ultimo == null) {
      _x = nx;
      _y = ny;
    } else {
      final dt = t.difference(ultimo).inMicroseconds / 1e6;
      final a = dt <= 0 ? 0.0 : 1 - math.exp(-dt / tau);
      _x = _x! + (nx - _x!) * a;
      _y = _y! + (ny - _y!) * a;
    }
    _t = t;
    return valor;
  }

  void reiniciar() {
    _x = null;
    _y = null;
    _t = null;
  }
}
