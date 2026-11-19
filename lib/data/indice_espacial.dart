import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'geo.dart';

/// Arista del grafo más cercana a un punto, con la proyección sobre ella.
@immutable
class ProyeccionArista {
  const ProyeccionArista({
    required this.arista,
    required this.t,
    required this.punto,
    required this.distancia,
  });

  /// Índice de la arista (no dirigida) en el arreglo del índice.
  final int arista;

  /// Posición sobre la arista: 0 = extremo `a`, 1 = extremo `b`.
  final double t;

  /// Punto proyectado, en metros locales.
  final PuntoXY punto;

  /// Distancia del punto consultado a la arista.
  final double distancia;
}

/// Índice espacial por celdas (rejilla uniforme) sobre los nodos y aristas
/// del grafo peatonal. Sustituye los barridos lineales de 1 940 nodos /
/// 10 484 aristas por búsquedas en anillos alrededor del punto.
class IndiceEspacial {
  IndiceEspacial({
    required Float64List x,
    required Float64List y,
    required Int32List aristaA,
    required Int32List aristaB,
    this.celda = 8,
  })  : _x = x,
        _y = y,
        _aristaA = aristaA,
        _aristaB = aristaB {
    _construir();
  }

  final Float64List _x;
  final Float64List _y;
  final Int32List _aristaA;
  final Int32List _aristaB;

  /// Lado de la celda en metros.
  final double celda;

  late double _minX, _minY;
  late int _cols, _filas;
  late List<List<int>> _nodosPorCelda;
  late List<List<int>> _aristasPorCelda;
  late Int32List _sello;
  int _consulta = 0;

  int get numNodos => _x.length;
  int get numAristas => _aristaA.length;

  void _construir() {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (var i = 0; i < _x.length; i++) {
      minX = math.min(minX, _x[i]);
      minY = math.min(minY, _y[i]);
      maxX = math.max(maxX, _x[i]);
      maxY = math.max(maxY, _y[i]);
    }
    if (_x.isEmpty) {
      minX = minY = 0;
      maxX = maxY = 1;
    }
    _minX = minX - celda;
    _minY = minY - celda;
    _cols = ((maxX - _minX) / celda).ceil() + 2;
    _filas = ((maxY - _minY) / celda).ceil() + 2;
    _nodosPorCelda = List.generate(_cols * _filas, (_) => <int>[]);
    _aristasPorCelda = List.generate(_cols * _filas, (_) => <int>[]);
    _sello = Int32List(_aristaA.length);

    for (var i = 0; i < _x.length; i++) {
      _nodosPorCelda[_celdaDe(_x[i], _y[i])].add(i);
    }
    // Cada arista se registra en todas las celdas que atraviesa (muestreo
    // cada 2 m): así una arista larga se encuentra desde cualquier punto.
    for (var e = 0; e < _aristaA.length; e++) {
      final a = _aristaA[e], b = _aristaB[e];
      final dx = _x[b] - _x[a], dy = _y[b] - _y[a];
      final largo = math.sqrt(dx * dx + dy * dy);
      final pasos = math.max(1, (largo / 2).ceil());
      var ultima = -1;
      for (var k = 0; k <= pasos; k++) {
        final t = k / pasos;
        final c = _celdaDe(_x[a] + dx * t, _y[a] + dy * t);
        if (c != ultima) {
          final lista = _aristasPorCelda[c];
          if (lista.isEmpty || lista.last != e) lista.add(e);
          ultima = c;
        }
      }
    }
  }

  int _col(double x) => ((x - _minX) / celda).floor().clamp(0, _cols - 1);
  int _fila(double y) => ((y - _minY) / celda).floor().clamp(0, _filas - 1);
  int _celdaDe(double x, double y) => _fila(y) * _cols + _col(x);

  /// Cota inferior de la distancia desde (px, py) a cualquier celda que quede
  /// fuera de los anillos 0..k ya revisados (para saber cuándo parar).
  double _cota(double px, double py, int k) {
    final dxFuera = math.max(
        0.0, math.max(_minX - px, px - (_minX + _cols * celda)));
    final dyFuera = math.max(
        0.0, math.max(_minY - py, py - (_minY + _filas * celda)));
    final m = math.min(dxFuera, dyFuera);
    final r = k * celda;
    return math.sqrt(r * r + m * m);
  }

  Iterable<int> _anillo(int c0, int f0, int k) sync* {
    if (k == 0) {
      yield f0 * _cols + c0;
      return;
    }
    for (var c = c0 - k; c <= c0 + k; c++) {
      for (final f in [f0 - k, f0 + k]) {
        if (c >= 0 && c < _cols && f >= 0 && f < _filas) yield f * _cols + c;
      }
    }
    for (var f = f0 - k + 1; f <= f0 + k - 1; f++) {
      for (final c in [c0 - k, c0 + k]) {
        if (c >= 0 && c < _cols && f >= 0 && f < _filas) yield f * _cols + c;
      }
    }
  }

  /// Nodo más cercano a (px, py) dentro de `radioMax`, o `null`.
  int? nodoMasCercano(
    double px,
    double py, {
    double radioMax = double.infinity,
    bool Function(int nodo)? filtro,
  }) {
    if (_x.isEmpty) return null;
    final c0 = _col(px), f0 = _fila(py);
    final maxK = math.max(_cols, _filas);
    int? mejor;
    var mejorD = double.infinity;
    for (var k = 0; k <= maxK; k++) {
      for (final celda in _anillo(c0, f0, k)) {
        for (final n in _nodosPorCelda[celda]) {
          if (filtro != null && !filtro(n)) continue;
          final dx = _x[n] - px, dy = _y[n] - py;
          final d = math.sqrt(dx * dx + dy * dy);
          if (d < mejorD) {
            mejorD = d;
            mejor = n;
          }
        }
      }
      final cota = _cota(px, py, k);
      if (mejorD <= cota || cota > radioMax) break;
    }
    return mejorD <= radioMax ? mejor : null;
  }

  /// Arista más cercana a (px, py) dentro de `radioMax`, o `null`.
  ProyeccionArista? aristaMasCercana(
    double px,
    double py, {
    double radioMax = 30,
    bool Function(int arista)? filtro,
  }) {
    if (_aristaA.isEmpty) return null;
    final p = PuntoXY(px, py);
    final c0 = _col(px), f0 = _fila(py);
    final maxK = math.max(_cols, _filas);
    _consulta++;
    ProyeccionArista? mejor;
    for (var k = 0; k <= maxK; k++) {
      for (final celda in _anillo(c0, f0, k)) {
        for (final e in _aristasPorCelda[celda]) {
          if (_sello[e] == _consulta) continue;
          _sello[e] = _consulta;
          if (filtro != null && !filtro(e)) continue;
          final a = _aristaA[e], b = _aristaB[e];
          final pr = proyectarEnSegmento(
              p, PuntoXY(_x[a], _y[a]), PuntoXY(_x[b], _y[b]));
          if (mejor == null || pr.distancia < mejor.distancia) {
            mejor = ProyeccionArista(
                arista: e, t: pr.t, punto: pr.punto, distancia: pr.distancia);
          }
        }
      }
      final cota = _cota(px, py, k);
      if ((mejor != null && mejor.distancia <= cota) || cota > radioMax) break;
    }
    if (mejor == null || mejor.distancia > radioMax) return null;
    return mejor;
  }
}
