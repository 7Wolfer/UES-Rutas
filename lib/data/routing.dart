import 'package:flutter/material.dart';

import '../core/formato.dart';
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
  });

  final List<NodoRuta> nodos;
  final List<Punto> puntos;

  /// Distancia total en unidades del mapa (aprox. metros para la demo).
  final double distancia;

  /// `true` si se pidió (y se encontró) una ruta que evita escaleras.
  final bool accesible;
  final bool usaEscaleras;
  final bool usaElevador;
  final bool usaRampa;

  /// Estimación de tiempo caminando a ~1.3 m/s.
  Duration get duracionEstimada =>
      Duration(seconds: (distancia / 1.3).round());

  bool get sinRuta => nodos.isEmpty;
}

/// Motor de ruteo muy simple (Dijkstra) sobre el grafo del campus.
///
/// Para la demo el grafo se arma a mano en `assets/seed/rutas.json`. Cuando
/// existan planos reales, este mismo motor sirve sobre un grafo generado.
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
      // Grafo no dirigido: agrega la arista inversa.
      m.putIfAbsent(a.b, () => []).add(
            AristaRuta(a: a.b, b: a.a, tipo: a.tipo),
          );
    }
    return m;
  }

  /// Nodo más cercano a un punto (para "engancharse" al grafo desde un espacio).
  String? _nodoMasCercano(Punto p, {int? nivel}) {
    String? mejor;
    var mejorD = double.infinity;
    for (final n in _nodos.values) {
      if (nivel != null && n.nivel != nivel) continue;
      final d = n.punto.distanciaA(p);
      if (d < mejorD) {
        mejorD = d;
        mejor = n.id;
      }
    }
    return mejor;
  }

  /// Calcula la ruta entre dos espacios. Si [accesible] es `true`, evita
  /// escaleras (usa rampas y elevadores).
  RutaCalculada calcular({
    required Espacio origen,
    required Espacio destino,
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

    final idOrigen = origen.id.let((id) =>
        _nodos.containsKey('n_$id') ? 'n_$id' : _nodoMasCercano(origen.punto));
    final idDestino = destino.id.let((id) =>
        _nodos.containsKey('n_$id') ? 'n_$id' : _nodoMasCercano(destino.punto));
    if (idOrigen == null || idDestino == null) return vacio;

    final dist = <String, double>{idOrigen: 0};
    final prev = <String, String>{};
    final visit = <String>{};
    final cola = PriorityQueue<_Item>((a, b) => a.d.compareTo(b.d))
      ..add(_Item(idOrigen, 0));

    while (cola.isNotEmpty) {
      final actual = cola.removeFirst();
      if (!visit.add(actual.id)) continue;
      if (actual.id == idDestino) break;

      for (final arista in _ady[actual.id] ?? const <AristaRuta>[]) {
        if (accesible && !arista.esAccesible) continue;
        final na = _nodos[actual.id]!;
        final nb = _nodos[arista.b];
        if (nb == null) continue;
        // Penaliza cambios de nivel para que la ruta prefiera un solo piso.
        final penal = arista.tipo == TipoArista.escalera ||
                arista.tipo == TipoArista.rampa ||
                arista.tipo == TipoArista.elevador
            ? 12.0
            : 0.0;
        final nd = actual.d + na.punto.distanciaA(nb.punto) + penal;
        if (nd < (dist[arista.b] ?? double.infinity)) {
          dist[arista.b] = nd;
          prev[arista.b] = actual.id;
          cola.add(_Item(arista.b, nd));
        }
      }
    }

    if (!prev.containsKey(idDestino) && idOrigen != idDestino) return vacio;

    // Reconstruye el camino.
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
      final t = _tipoEntre(ids[i], ids[i + 1]);
      if (t == TipoArista.escalera) usaEsc = true;
      if (t == TipoArista.elevador) usaElev = true;
      if (t == TipoArista.rampa) usaRampa = true;
    }

    return RutaCalculada(
      nodos: nodos,
      puntos: nodos.map((n) => n.punto).toList(),
      distancia: dist[idDestino] ?? 0,
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

  /// Convierte la ruta en pasos legibles para mostrar en la UI.
  List<PasoRuta> describir(
    RutaCalculada r, {
    required Espacio origen,
    required Espacio destino,
  }) {
    if (r.sinRuta || r.nodos.length < 2) return const [];
    final pasos = <PasoRuta>[
      PasoRuta(Icons.trip_origin, 'Sales de ${origen.titulo}'),
    ];

    var caminado = 0.0;
    void volcarCaminata() {
      if (caminado > 4) {
        pasos.add(PasoRuta(
          Icons.directions_walk,
          'Caminas ${caminado.round()} m',
        ));
      }
      caminado = 0;
    }

    for (var i = 0; i < r.nodos.length - 1; i++) {
      final a = r.nodos[i], b = r.nodos[i + 1];
      final tipo = _tipoEntre(a.id, b.id) ?? TipoArista.pasillo;
      final d = a.punto.distanciaA(b.punto);
      switch (tipo) {
        case TipoArista.exterior:
        case TipoArista.pasillo:
        case TipoArista.puerta:
          caminado += d;
        case TipoArista.escalera:
          volcarCaminata();
          final sube = b.nivel > a.nivel;
          pasos.add(PasoRuta(
            Icons.stairs_outlined,
            '${sube ? 'Subes' : 'Bajas'} por la escalera a ${etiquetaNivel(b.nivel)}',
          ));
        case TipoArista.rampa:
          volcarCaminata();
          pasos.add(const PasoRuta(Icons.accessible, 'Tomas la rampa de acceso'));
        case TipoArista.elevador:
          volcarCaminata();
          if (b.nivel != a.nivel) {
            pasos.add(PasoRuta(
              Icons.elevator_outlined,
              'Tomas el elevador a ${etiquetaNivel(b.nivel)}',
            ));
          }
      }
    }
    volcarCaminata();
    pasos.add(PasoRuta(Icons.place, 'Llegas a ${destino.titulo}'));
    return pasos;
  }
}

@immutable
class PasoRuta {
  const PasoRuta(this.icono, this.texto);
  final IconData icono;
  final String texto;
}

class _Item {
  _Item(this.id, this.d);
  final String id;
  final double d;
}

/// Cola de prioridad mínima (binary heap). Evita depender de `package:collection`
/// para esto y mantiene el motor autocontenido.
class PriorityQueue<E> {
  PriorityQueue(this._compare);

  final int Function(E, E) _compare;
  final List<E> _heap = [];

  bool get isNotEmpty => _heap.isNotEmpty;

  void add(E value) {
    _heap.add(value);
    var i = _heap.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_compare(_heap[i], _heap[parent]) >= 0) break;
      _swap(i, parent);
      i = parent;
    }
  }

  E removeFirst() {
    final first = _heap.first;
    final last = _heap.removeLast();
    if (_heap.isNotEmpty) {
      _heap[0] = last;
      var i = 0;
      final n = _heap.length;
      while (true) {
        final l = 2 * i + 1;
        final r = 2 * i + 2;
        var smallest = i;
        if (l < n && _compare(_heap[l], _heap[smallest]) < 0) smallest = l;
        if (r < n && _compare(_heap[r], _heap[smallest]) < 0) smallest = r;
        if (smallest == i) break;
        _swap(i, smallest);
        i = smallest;
      }
    }
    return first;
  }

  void _swap(int a, int b) {
    final t = _heap[a];
    _heap[a] = _heap[b];
    _heap[b] = t;
  }
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
