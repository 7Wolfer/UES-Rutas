import 'package:flutter/material.dart';

import 'models.dart';

/// Resultado de un cálculo de ruta peatonal.
class RutaCalculada {
  RutaCalculada({
    required this.nodos,
    required this.puntos,
    required this.distancia,
    required this.accesible,
    required this.usaEscaleras,
    required this.usaElevador,
    required this.usaRampa,
    this.aproxOrigen = 0,
  });

  final List<NodoRuta> nodos;
  final List<Punto> puntos;

  /// Distancia total en metros (incluye el tramo de aproximación en cada extremo).
  final double distancia;

  /// Metros entre el origen real y el primer nodo del camino. Útil cuando el
  /// origen es la ubicación del usuario y queda lejos de la red peatonal.
  final double aproxOrigen;

  final bool accesible;
  final bool usaEscaleras;
  final bool usaElevador;
  final bool usaRampa;

  /// Caminando a ~1.35 m/s.
  Duration get duracionEstimada =>
      Duration(seconds: (distancia / 1.35).round());

  bool get sinRuta => nodos.isEmpty;
}

/// Motor de ruteo (Dijkstra) sobre el grafo peatonal del campus.
class MotorRutas {
  MotorRutas(CampusData data)
      : _nodos = {for (final n in data.nodos) n.id: n},
        _ady = _construirAdyacencia(data);

  final Map<String, NodoRuta> _nodos;
  final Map<String, List<AristaRuta>> _ady;

  static Map<String, List<AristaRuta>> _construirAdyacencia(CampusData data) {
    final m = <String, List<AristaRuta>>{};
    for (final a in data.aristas) {
      m.putIfAbsent(a.a, () => []).add(a);
      m
          .putIfAbsent(a.b, () => [])
          .add(AristaRuta(a: a.b, b: a.a, tipo: a.tipo));
    }
    return m;
  }

  String? _nodoMasCercano(Punto p) {
    String? mejor;
    var mejorD = double.infinity;
    for (final n in _nodos.values) {
      final d = n.punto.distanciaA(p);
      if (d < mejorD) {
        mejorD = d;
        mejor = n.id;
      }
    }
    return mejor;
  }

  RutaCalculada calcular({
    required Lugar origen,
    required Lugar destino,
    required bool accesible,
  }) {
    final vacio = RutaCalculada(
      nodos: const [],
      puntos: const [],
      distancia: 0,
      accesible: accesible,
      usaEscaleras: false,
      usaElevador: false,
      usaRampa: false,
    );

    final idOrigen = _nodos.containsKey('n_${origen.id}')
        ? 'n_${origen.id}'
        : _nodoMasCercano(origen.punto);
    final idDestino = _nodos.containsKey('n_${destino.id}')
        ? 'n_${destino.id}'
        : _nodoMasCercano(destino.punto);
    if (idOrigen == null || idDestino == null) return vacio;
    if (idOrigen == idDestino) return vacio;

    final dist = <String, double>{idOrigen: 0};
    final prev = <String, String>{};
    final visit = <String>{};
    final cola = _MinHeap()..add(idOrigen, 0);

    while (cola.isNotEmpty) {
      final actual = cola.removeMin();
      if (!visit.add(actual)) continue;
      if (actual == idDestino) break;
      final na = _nodos[actual]!;
      for (final arista in _ady[actual] ?? const <AristaRuta>[]) {
        if (accesible && !arista.esAccesible) continue;
        final nb = _nodos[arista.b];
        if (nb == null) continue;
        final penal = switch (arista.tipo) {
          TipoArista.escalera ||
          TipoArista.rampa ||
          TipoArista.elevador =>
            15.0,
          _ => 0.0,
        };
        final nd = dist[actual]! + na.punto.distanciaA(nb.punto) + penal;
        if (nd < (dist[arista.b] ?? double.infinity)) {
          dist[arista.b] = nd;
          prev[arista.b] = actual;
          cola.add(arista.b, nd);
        }
      }
    }

    if (!prev.containsKey(idDestino)) return vacio;

    final ids = <String>[idDestino];
    var cur = idDestino;
    while (cur != idOrigen) {
      final p = prev[cur];
      if (p == null) break;
      ids.insert(0, p);
      cur = p;
    }

    final nodos = ids.map((id) => _nodos[id]!).toList();
    var usaEsc = false, usaElev = false, usaRampa = false;
    for (var i = 0; i < ids.length - 1; i++) {
      switch (_tipoEntre(ids[i], ids[i + 1])) {
        case TipoArista.escalera:
          usaEsc = true;
        case TipoArista.elevador:
          usaElev = true;
        case TipoArista.rampa:
          usaRampa = true;
        default:
      }
    }

    final aproxOrigen = origen.punto.distanciaA(nodos.first.punto);
    final aproxDestino = destino.punto.distanciaA(nodos.last.punto);

    return RutaCalculada(
      nodos: nodos,
      puntos: [origen.punto, ...nodos.map((n) => n.punto), destino.punto],
      distancia: (dist[idDestino] ?? 0) + aproxOrigen + aproxDestino,
      aproxOrigen: aproxOrigen,
      accesible: accesible,
      usaEscaleras: usaEsc,
      usaElevador: usaElev,
      usaRampa: usaRampa,
    );
  }

  TipoArista? _tipoEntre(String a, String b) {
    for (final ar in _ady[a] ?? const <AristaRuta>[]) {
      if (ar.b == b) return ar.tipo;
    }
    return null;
  }

  /// Pasos legibles de la ruta.
  List<PasoRuta> describir(
    RutaCalculada r, {
    required Lugar origen,
    required Lugar destino,
  }) {
    if (r.sinRuta || r.nodos.length < 2) return const [];
    final pasos = <PasoRuta>[
      PasoRuta(Icons.trip_origin, 'Sales de ${origen.nombre}'),
    ];

    var caminado = 0.0;
    void volcar() {
      if (caminado > 8) {
        pasos.add(PasoRuta(
          Icons.directions_walk,
          'Caminas ${caminado.round()} m por el campus',
        ));
      }
      caminado = 0;
    }

    for (var i = 0; i < r.nodos.length - 1; i++) {
      final a = r.nodos[i], b = r.nodos[i + 1];
      final tipo = _tipoEntre(a.id, b.id) ?? TipoArista.exterior;
      final d = a.punto.distanciaA(b.punto);
      switch (tipo) {
        case TipoArista.escalera:
          volcar();
          pasos.add(
              const PasoRuta(Icons.stairs_outlined, 'Subes por la escalinata'));
        case TipoArista.rampa:
          volcar();
          pasos.add(
              const PasoRuta(Icons.accessible, 'Tomas la rampa de acceso'));
        case TipoArista.elevador:
          volcar();
          pasos.add(
              const PasoRuta(Icons.elevator_outlined, 'Tomas el elevador'));
        default:
          caminado += d;
      }
    }
    volcar();
    pasos.add(PasoRuta(Icons.place, 'Llegas a ${destino.nombre}'));
    return pasos;
  }
}

@immutable
class PasoRuta {
  const PasoRuta(this.icono, this.texto);
  final IconData icono;
  final String texto;
}

/// Min-heap sobre (nodeId, dist). Permite entradas duplicadas; el visitado
/// se filtra en el bucle principal.
class _MinHeap {
  final List<(String, double)> _h = [];

  bool get isNotEmpty => _h.isNotEmpty;

  void _swap(int a, int b) {
    final t = _h[a];
    _h[a] = _h[b];
    _h[b] = t;
  }

  void add(String id, double d) {
    _h.add((id, d));
    var i = _h.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_h[i].$2 >= _h[p].$2) break;
      _swap(i, p);
      i = p;
    }
  }

  String removeMin() {
    final top = _h.first;
    final last = _h.removeLast();
    if (_h.isNotEmpty) {
      _h[0] = last;
      var i = 0;
      final n = _h.length;
      while (true) {
        final l = 2 * i + 1, rr = 2 * i + 2;
        var m = i;
        if (l < n && _h[l].$2 < _h[m].$2) m = l;
        if (rr < n && _h[rr].$2 < _h[m].$2) m = rr;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
    return top.$1;
  }
}
