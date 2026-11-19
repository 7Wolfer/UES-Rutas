import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'campus_geo.dart';
import 'geo.dart';
import 'models.dart';

/// Velocidades al caminar (m/s) que ofrece Ajustes.
abstract final class VelocidadMarcha {
  static const double lenta = 1.0;
  static const double normal = 1.3;
  static const double rapida = 1.6;
}

/// Cuánto más lento se recorre cada tipo de tramo respecto a caminar en plano.
double factorTiempo(TipoArista t) => switch (t) {
      TipoArista.escalera => 2.0,
      TipoArista.rampa => 1.18,
      TipoArista.pasillo => 1.05,
      _ => 1.0,
    };

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
    this.aproxDestino = 0,
    this.costo = 0,
    this.acumulado = const [],
    this.tipos = const [],
  });

  factory RutaCalculada.vacia({required bool accesible}) => RutaCalculada(
        nodos: const [],
        puntos: const [],
        distancia: 0,
        accesible: accesible,
        usaEscaleras: false,
        usaElevador: false,
        usaRampa: false,
      );

  /// Nodos del grafo que recorre la ruta (sin los tramos de aproximación).
  final List<NodoRuta> nodos;

  /// Polilínea completa, del origen real al destino real.
  final List<Punto> puntos;

  /// Distancia real en metros (sin penalizaciones), con los tramos de
  /// aproximación en cada extremo. Es la que se muestra.
  final double distancia;

  /// Metros entre el origen real y la red peatonal (0 si el origen es un
  /// lugar del catálogo). Útil cuando el origen es la ubicación del usuario.
  final double aproxOrigen;

  /// Igual que [aproxOrigen], en el extremo del destino.
  final double aproxDestino;

  /// Costo que minimizó el motor: distancia + penalizaciones por escaleras,
  /// rampas y elevadores. Solo sirve para comparar rutas.
  final double costo;

  /// Distancia acumulada en cada punto de [puntos] (`acumulado.last == distancia`).
  final List<double> acumulado;

  /// Tipo de cada tramo: `tipos[i]` va de `puntos[i]` a `puntos[i + 1]`.
  final List<TipoArista> tipos;

  final bool accesible;
  final bool usaEscaleras;
  final bool usaElevador;
  final bool usaRampa;

  /// Tiempo a pie a una velocidad dada, tramo por tramo (las escaleras y
  /// rampas cuestan más; un elevador suma su espera).
  Duration duracionPara(double velocidadMs) {
    if (tipos.isEmpty || acumulado.length != tipos.length + 1) {
      return Duration(seconds: (distancia / velocidadMs).round());
    }
    var s = 0.0;
    for (var i = 0; i < tipos.length; i++) {
      final largo = acumulado[i + 1] - acumulado[i];
      s += tipos[i] == TipoArista.elevador
          ? 40 + largo / 0.5
          : largo * factorTiempo(tipos[i]) / velocidadMs;
    }
    return Duration(seconds: s.round());
  }

  /// A paso normal.
  Duration get duracionEstimada => duracionPara(VelocidadMarcha.normal);

  bool get sinRuta => nodos.isEmpty;
}

/// Motor de ruteo A* sobre el grafo peatonal del campus.
///
/// Trabaja con índices enteros y arreglos tipados (adyacencia compacta). La
/// heurística (0.995 × distancia en línea recta) es admisible porque cada
/// arista cuesta al menos su largo y las penalizaciones nunca son negativas;
/// da exactamente las mismas rutas que Dijkstra expandiendo muchos menos nodos.
class MotorRutas {
  MotorRutas(CampusData data) : this.conGeo(CampusGeo(data));

  MotorRutas.conGeo(this.geo) {
    final n = geo.nodoX.length;
    final m = geo.aristaA.length;
    final grado = Int32List(n + 1);
    for (var e = 0; e < m; e++) {
      grado[geo.aristaA[e] + 1]++;
      grado[geo.aristaB[e] + 1]++;
    }
    for (var i = 0; i < n; i++) {
      grado[i + 1] += grado[i];
    }
    _inicio = grado;
    _vecino = Int32List(2 * m);
    _arista = Int32List(2 * m);
    _largo = Float64List(2 * m);
    final cursor = Int32List.fromList(grado.sublist(0, n));
    for (var e = 0; e < m; e++) {
      final a = geo.aristaA[e], b = geo.aristaB[e];
      final largo = geo.nodo(a).punto.distanciaA(geo.nodo(b).punto);
      _largoArista[e] = largo;
      final ka = cursor[a]++, kb = cursor[b]++;
      _vecino[ka] = b;
      _arista[ka] = e;
      _largo[ka] = largo;
      _vecino[kb] = a;
      _arista[kb] = e;
      _largo[kb] = largo;
    }
  }

  /// El campus en metros (índice espacial, edificios, perímetro).
  final CampusGeo geo;

  late final Int32List _inicio;
  late final Int32List _vecino;
  late final Int32List _arista;
  late final Float64List _largo;
  late final Float64List _largoArista = Float64List(geo.aristaA.length);

  /// Radio para enganchar un punto libre a la arista más cercana.
  static const double radioEnganche = 40;

  /// Penalización (en metros equivalentes) por tipo de tramo.
  /// `double.infinity` = prohibido en ese modo.
  static double penalizacion(TipoArista t, {required bool accesible}) =>
      switch (t) {
        TipoArista.escalera => accesible ? double.infinity : 15,
        TipoArista.rampa => accesible ? 0 : 3,
        TipoArista.elevador => accesible ? 0 : 25,
        TipoArista.puerta => 2,
        _ => 0,
      };

  RutaCalculada calcular({
    required Lugar origen,
    required Lugar destino,
    required bool accesible,
  }) {
    if (origen.id == destino.id && origen.id != Lugar.idMiUbicacion) {
      return RutaCalculada.vacia(accesible: accesible);
    }
    final ini = _extremo(origen, accesible: accesible, esDestino: false);
    final fin = _extremo(destino, accesible: accesible, esDestino: true);
    if (ini == null || fin == null) {
      return RutaCalculada.vacia(accesible: accesible);
    }

    final res = _aEstrella(ini, fin, accesible: accesible);
    if (res == null) return RutaCalculada.vacia(accesible: accesible);
    final (camino, aristas, costo) = res;

    // --- Polilínea: aproximación + nodos + aproximación ---
    final puntos = <Punto>[];
    final tipos = <TipoArista>[];
    void agregar(Punto p, TipoArista tipoDesdeAnterior) {
      if (puntos.isNotEmpty && puntos.last.distanciaA(p) < 0.05) return;
      if (puntos.isNotEmpty) tipos.add(tipoDesdeAnterior);
      puntos.add(p);
    }

    final primero = camino.first;
    for (final p in ini.prefijo(primero)) {
      agregar(p.$1, p.$2);
    }
    agregar(geo.nodo(primero).punto, ini.tipoHacia(primero));
    for (var i = 1; i < camino.length; i++) {
      agregar(geo.nodo(camino[i]).punto, geo.tipoArista(aristas[i]));
    }
    final ultimo = camino.last;
    for (final p in fin.sufijo(ultimo)) {
      agregar(p.$1, p.$2);
    }

    final acumulado = <double>[0];
    for (var i = 1; i < puntos.length; i++) {
      acumulado.add(acumulado.last + puntos[i - 1].distanciaA(puntos[i]));
    }

    return RutaCalculada(
      nodos: [for (final i in camino) geo.nodo(i)],
      puntos: puntos,
      distancia: acumulado.last,
      aproxOrigen: ini.aproximacion,
      aproxDestino: fin.aproximacion,
      costo: costo,
      acumulado: acumulado,
      tipos: tipos,
      accesible: accesible,
      usaEscaleras: tipos.contains(TipoArista.escalera),
      usaElevador: tipos.contains(TipoArista.elevador),
      usaRampa: tipos.contains(TipoArista.rampa),
    );
  }

  /// Cómo se entra (o sale) del grafo para un lugar o un punto libre.
  _Extremo? _extremo(Lugar l, {required bool accesible, required bool esDestino}) {
    // 1) Lugar del catálogo: su(s) nodo(s) de entrada.
    final entradas = geo.nodosPorLugar[l.id];
    if (entradas != null && entradas.isNotEmpty) {
      return _Extremo.nodos({for (final n in entradas) n: 0.0},
          objetivo: geo.xyNodo(entradas.first));
    }

    final p = geo.geo.aXY(l.punto);
    // 2) Dentro de un edificio: se sale (o se llega) por su entrada.
    final edificio = geo.edificioEn(p);
    final puertas =
        edificio == null ? null : geo.nodosPorLugar[edificio.lugar.id];
    if (puertas != null && puertas.isNotEmpty) {
      final costos = <int, double>{
        for (final n in puertas) n: p.distanciaA(geo.xyNodo(n)),
      };
      return _Extremo.interior(l.punto, costos,
          objetivo: p, esDestino: esDestino);
    }

    // 3) Punto libre: la arista más cercana a la que se llega sin atravesar
    //    edificios (y sin escaleras en modo accesible).
    final pr = geo.indice.aristaMasCercana(
      p.x,
      p.y,
      radioMax: radioEnganche,
      filtro: (e) {
        if (accesible && geo.tipoArista(e) == TipoArista.escalera) return false;
        final a = geo.aristaA[e], b = geo.aristaB[e];
        final q = proyectarEnSegmento(p, geo.xyNodo(a), geo.xyNodo(b)).punto;
        return !geo.cruzaEdificio(p, q);
      },
    );
    if (pr != null) {
      final a = geo.aristaA[pr.arista], b = geo.aristaB[pr.arista];
      final largo = _largoArista[pr.arista];
      return _Extremo.arista(
        punto: l.punto,
        proyeccion: geo.geo.aPunto(pr.punto),
        aproximacion: pr.distancia,
        a: a,
        b: b,
        costoA: pr.t * largo,
        costoB: (1 - pr.t) * largo,
        tipo: geo.tipoArista(pr.arista),
        objetivo: pr.punto,
        esDestino: esDestino,
      );
    }

    // 4) Lejos de todo (fuera del campus): el nodo más cercano, en recta.
    final n = geo.indice.nodoMasCercano(p.x, p.y);
    if (n == null) return null;
    // La heurística apunta al nodo (no al punto lejano): el tramo recto se
    // suma aparte y no debe sobrestimar lo que falta dentro del grafo.
    return _Extremo.lejano(l.punto, n,
        aproximacion: p.distanciaA(geo.xyNodo(n)),
        objetivo: geo.xyNodo(n),
        esDestino: esDestino);
  }

  (List<int>, List<int>, double)? _aEstrella(
    _Extremo ini,
    _Extremo fin, {
    required bool accesible,
  }) {
    final n = geo.nodoX.length;
    final g = Float64List(n)..fillRange(0, n, double.infinity);
    final prev = Int32List(n)..fillRange(0, n, -1);
    final prevArista = Int32List(n)..fillRange(0, n, -1);
    final cerrado = Uint8List(n);
    final ox = fin.objetivo.x, oy = fin.objetivo.y;
    double h(int v) {
      final dx = geo.nodoX[v] - ox, dy = geo.nodoY[v] - oy;
      return 0.995 * math.sqrt(dx * dx + dy * dy);
    }

    final cola = _MonticuloMin();
    ini.costos.forEach((nodo, c) {
      if (c < g[nodo]) {
        g[nodo] = c;
        cola.agregar(nodo, c + h(nodo));
      }
    });

    var meta = -1;
    var mejorTotal = double.infinity;
    while (cola.noVacio) {
      final f = cola.claveMin;
      final u = cola.quitarMin();
      if (f >= mejorTotal) break;
      if (cerrado[u] == 1) continue;
      cerrado[u] = 1;
      final extra = fin.costos[u];
      if (extra != null && g[u] + extra < mejorTotal) {
        mejorTotal = g[u] + extra;
        meta = u;
      }
      for (var k = _inicio[u]; k < _inicio[u + 1]; k++) {
        final v = _vecino[k];
        if (cerrado[v] == 1) continue;
        final e = _arista[k];
        final pen = penalizacion(geo.tipoArista(e), accesible: accesible);
        if (pen == double.infinity) continue;
        final nd = g[u] + _largo[k] + pen;
        if (nd < g[v]) {
          g[v] = nd;
          prev[v] = u;
          prevArista[v] = e;
          cola.agregar(v, nd + h(v));
        }
      }
    }
    if (meta < 0) return null;

    final camino = <int>[];
    final aristas = <int>[];
    for (var v = meta; v >= 0; v = prev[v]) {
      camino.add(v);
      aristas.add(prevArista[v]);
    }
    return (
      camino.reversed.toList(),
      aristas.reversed.toList(),
      mejorTotal + ini.aproximacion + fin.aproximacion,
    );
  }

  /// Pasos legibles de la ruta (versión breve, para la lista de indicaciones).
  List<PasoRuta> describir(
    RutaCalculada r, {
    required Lugar origen,
    required Lugar destino,
  }) {
    if (r.sinRuta || r.puntos.length < 2) return const [];
    final pasos = <PasoRuta>[
      PasoRuta(Icons.trip_origin, 'Sales de ${origen.nombre}'),
    ];

    var caminado = 0.0;
    void volcar() {
      if (caminado > 8) {
        pasos.add(PasoRuta(
          Icons.directions_walk,
          'Caminas ${caminado.round()} m por el campus',
          distanciaM: caminado,
        ));
      }
      caminado = 0;
    }

    for (var i = 0; i < r.tipos.length; i++) {
      final d = r.acumulado[i + 1] - r.acumulado[i];
      switch (r.tipos[i]) {
        case TipoArista.escalera:
          volcar();
          pasos.add(PasoRuta(Icons.stairs_outlined, 'Tomas la escalinata',
              distanciaM: d));
        case TipoArista.rampa:
          volcar();
          pasos.add(PasoRuta(Icons.accessible, 'Tomas la rampa de acceso',
              distanciaM: d));
        case TipoArista.elevador:
          volcar();
          pasos.add(PasoRuta(Icons.elevator_outlined, 'Tomas el elevador',
              distanciaM: d));
        default:
          caminado += d;
      }
    }
    volcar();
    pasos.add(PasoRuta(Icons.place, 'Llegas a ${destino.nombre}'));
    return pasos;
  }
}

/// Un paso de la lista de indicaciones.
@immutable
class PasoRuta {
  const PasoRuta(this.icono, this.texto, {this.distanciaM});
  final IconData icono;
  final String texto;

  /// Metros que cubre el paso (si aplica).
  final double? distanciaM;
}

/// Forma de entrar o salir del grafo en un extremo de la ruta.
class _Extremo {
  _Extremo._({
    required this.costos,
    required this.objetivo,
    this.aproximacion = 0,
    List<(Punto, TipoArista)> Function(int nodo)? camino,
    TipoArista Function(int nodo)? tipoHacia,
    this.esDestino = false,
  })  : _camino = camino,
        _tipoHacia = tipoHacia;

  /// Lugar del catálogo con nodo(s) de entrada propios.
  factory _Extremo.nodos(Map<int, double> nodos, {required PuntoXY objetivo}) =>
      _Extremo._(costos: nodos, objetivo: objetivo);

  /// Punto dentro de un edificio: se une en recta a sus puertas.
  factory _Extremo.interior(Punto p, Map<int, double> costos,
          {required PuntoXY objetivo, required bool esDestino}) =>
      _Extremo._(
        costos: costos,
        objetivo: objetivo,
        aproximacion: 0,
        camino: (_) => [(p, TipoArista.pasillo)],
        tipoHacia: (_) => TipoArista.pasillo,
        esDestino: esDestino,
      );

  /// Punto libre enganchado a una arista (a–b) en su proyección.
  factory _Extremo.arista({
    required Punto punto,
    required Punto proyeccion,
    required double aproximacion,
    required int a,
    required int b,
    required double costoA,
    required double costoB,
    required TipoArista tipo,
    required PuntoXY objetivo,
    required bool esDestino,
  }) =>
      _Extremo._(
        costos: {a: costoA, b: costoB},
        objetivo: objetivo,
        aproximacion: aproximacion,
        camino: (_) => [
          (punto, TipoArista.exterior),
          (proyeccion, TipoArista.exterior),
        ],
        tipoHacia: (_) => tipo,
        esDestino: esDestino,
      );

  /// Punto lejos de la red: tramo recto al nodo más cercano.
  factory _Extremo.lejano(Punto p, int nodo,
          {required double aproximacion,
          required PuntoXY objetivo,
          required bool esDestino}) =>
      _Extremo._(
        costos: {nodo: 0},
        objetivo: objetivo,
        aproximacion: aproximacion,
        camino: (_) => [(p, TipoArista.exterior)],
        tipoHacia: (_) => TipoArista.exterior,
        esDestino: esDestino,
      );

  /// Costo de partida (o de llegada) en cada nodo de enganche.
  final Map<int, double> costos;

  /// Punto hacia el que apunta la heurística (solo en el destino).
  final PuntoXY objetivo;

  /// Metros del tramo recto entre el punto real y la red.
  final double aproximacion;

  final bool esDestino;
  final List<(Punto, TipoArista)> Function(int nodo)? _camino;
  final TipoArista Function(int nodo)? _tipoHacia;

  /// Puntos antes del primer nodo, cada uno con el tipo del tramo que llega a
  /// él (el primero no lleva tramo previo).
  List<(Punto, TipoArista)> prefijo(int nodo) => _camino?.call(nodo) ?? const [];

  /// Puntos después del último nodo (orden inverso al del prefijo).
  List<(Punto, TipoArista)> sufijo(int nodo) {
    final c = _camino?.call(nodo);
    if (c == null) return const [];
    final tipo = tipoHacia(nodo);
    final inv = c.reversed.toList();
    // El primer tramo tras el último nodo es el de la arista enganchada (o el
    // del interior del edificio); los siguientes, el tramo recto.
    return [
      for (var i = 0; i < inv.length; i++)
        (inv[i].$1, i == 0 ? tipo : TipoArista.exterior),
    ];
  }

  /// Tipo del tramo que conecta el último punto del prefijo con el nodo.
  TipoArista tipoHacia(int nodo) =>
      _tipoHacia?.call(nodo) ?? TipoArista.exterior;
}

/// Montículo de mínimos sobre (nodo, clave). Admite duplicados: los nodos ya
/// cerrados se descartan en el bucle principal.
class _MonticuloMin {
  final List<int> _nodo = [];
  final List<double> _clave = [];

  bool get noVacio => _nodo.isNotEmpty;
  double get claveMin => _clave.first;

  void _intercambiar(int a, int b) {
    final tn = _nodo[a];
    _nodo[a] = _nodo[b];
    _nodo[b] = tn;
    final tc = _clave[a];
    _clave[a] = _clave[b];
    _clave[b] = tc;
  }

  void agregar(int nodo, double clave) {
    _nodo.add(nodo);
    _clave.add(clave);
    var i = _nodo.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_clave[i] >= _clave[p]) break;
      _intercambiar(i, p);
      i = p;
    }
  }

  int quitarMin() {
    final tope = _nodo.first;
    final ultimoNodo = _nodo.removeLast();
    final ultimaClave = _clave.removeLast();
    if (_nodo.isNotEmpty) {
      _nodo[0] = ultimoNodo;
      _clave[0] = ultimaClave;
      var i = 0;
      final n = _nodo.length;
      while (true) {
        final l = 2 * i + 1, r = 2 * i + 2;
        var m = i;
        if (l < n && _clave[l] < _clave[m]) m = l;
        if (r < n && _clave[r] < _clave[m]) m = r;
        if (m == i) break;
        _intercambiar(i, m);
        i = m;
      }
    }
    return tope;
  }
}
