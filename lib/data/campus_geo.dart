import 'dart:typed_data';

import 'geo.dart';
import 'indice_espacial.dart';
import 'models.dart';

/// Polígono de un lugar ya proyectado a metros.
class PoligonoLugar {
  PoligonoLugar(this.lugar, this.anillo) : centro = centroide(anillo);

  final Lugar lugar;
  final List<PuntoXY> anillo;
  final PuntoXY centro;

  /// Los edificios estorban; explanadas y estacionamientos se cruzan.
  bool get esObstaculo => !lugar.transitable;
}

/// El campus en metros: grafo peatonal, edificios, perímetro e índice espacial.
/// Lo comparten el motor de rutas, las indicaciones y la navegación.
class CampusGeo {
  CampusGeo(this.data) : geo = GeoLocal(data.info.centro) {
    final n = data.nodos.length;
    nodoX = Float64List(n);
    nodoY = Float64List(n);
    for (var i = 0; i < n; i++) {
      final nodo = data.nodos[i];
      indicePorId[nodo.id] = i;
      final p = geo.aXY(nodo.punto);
      nodoX[i] = p.x;
      nodoY[i] = p.y;
      final lugarId = nodo.lugarId;
      if (lugarId != null) {
        (nodosPorLugar[lugarId] ??= <int>[]).add(i);
      }
    }
    final aristas = <AristaRuta>[
      for (final a in data.aristas)
        if (indicePorId.containsKey(a.a) && indicePorId.containsKey(a.b)) a,
    ];
    aristaA = Int32List(aristas.length);
    aristaB = Int32List(aristas.length);
    aristaTipo = Uint8List(aristas.length);
    for (var e = 0; e < aristas.length; e++) {
      aristaA[e] = indicePorId[aristas[e].a]!;
      aristaB[e] = indicePorId[aristas[e].b]!;
      aristaTipo[e] = aristas[e].tipo.index;
    }
    indice = IndiceEspacial(
        x: nodoX, y: nodoY, aristaA: aristaA, aristaB: aristaB);

    for (final l in data.lugares) {
      final poli = l.poligono;
      if (poli == null || poli.length < 3) continue;
      poligonos.add(PoligonoLugar(l, [for (final p in poli) geo.aXY(p)]));
    }
    perimetro = [for (final p in data.info.perimetro) geo.aXY(p)];
  }

  final CampusData data;
  final GeoLocal geo;

  final Map<String, int> indicePorId = {};

  /// Nodos de entrada de cada lugar (hoy uno por lugar: `n_<id>`).
  final Map<String, List<int>> nodosPorLugar = {};

  late final Float64List nodoX;
  late final Float64List nodoY;
  late final Int32List aristaA;
  late final Int32List aristaB;
  late final Uint8List aristaTipo;
  late final IndiceEspacial indice;
  final List<PoligonoLugar> poligonos = [];
  late final List<PuntoXY> perimetro;

  PuntoXY xyNodo(int i) => PuntoXY(nodoX[i], nodoY[i]);
  NodoRuta nodo(int i) => data.nodos[i];
  TipoArista tipoArista(int e) => TipoArista.values[aristaTipo[e]];

  /// ¿Está el punto dentro del perímetro del campus?
  bool dentroDelPerimetro(PuntoXY p) =>
      perimetro.length >= 3 && puntoEnPoligono(p, perimetro);

  /// Distancia del punto a la red peatonal (arista más cercana).
  double distanciaARed(PuntoXY p, {double radioMax = 2000}) =>
      indice.aristaMasCercana(p.x, p.y, radioMax: radioMax)?.distancia ??
      double.infinity;

  /// Edificio (no transitable) que contiene el punto, si lo hay.
  PoligonoLugar? edificioEn(PuntoXY p) {
    for (final pl in poligonos) {
      if (pl.esObstaculo && puntoEnPoligono(p, pl.anillo)) return pl;
    }
    return null;
  }

  /// Edificio más cercano a `p` a menos de `radio` metros.
  PoligonoLugar? edificioCercano(
    PuntoXY p, {
    double radio = 15,
    Set<String> excluir = const {},
  }) {
    PoligonoLugar? mejor;
    var mejorD = radio;
    for (final pl in poligonos) {
      if (!pl.esObstaculo || excluir.contains(pl.lugar.id)) continue;
      final d = distanciaAPoligono(p, pl.anillo);
      if (d <= mejorD) {
        mejorD = d;
        mejor = pl;
      }
    }
    return mejor;
  }

  /// ¿El tramo recto a–b atraviesa algún edificio?
  bool cruzaEdificio(PuntoXY a, PuntoXY b, {Set<String> excluir = const {}}) {
    for (final pl in poligonos) {
      if (!pl.esObstaculo || excluir.contains(pl.lugar.id)) continue;
      if (segmentoTocaPoligono(a, b, pl.anillo)) return true;
    }
    return false;
  }
}
