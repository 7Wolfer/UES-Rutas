import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/movimiento.dart';

/// Movimientos suaves de la cámara del mapa.
///
/// flutter_map 7 solo "salta" (`move`, `fitCamera`); esta clase interpola
/// centro, zoom y rotación cuadro a cuadro. También tiene un modo de
/// seguimiento continuo (navegación) que persigue un objetivo con suavizado
/// exponencial, y se detiene en cuanto el usuario toca el mapa.
class CamaraAnimada {
  CamaraAnimada({
    required this.controller,
    required TickerProvider vsync,
    required bool Function() reducirMovimiento,
  }) : _reducir = reducirMovimiento {
    _anim = AnimationController(vsync: vsync)
      ..addListener(_tickAnimacion)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _completar(true);
      });
    _ticker = vsync.createTicker(_tickSeguimiento);
    _sub = controller.mapEventStream.listen(_alEvento);
  }

  final MapController controller;
  final bool Function() _reducir;
  late final AnimationController _anim;
  late final Ticker _ticker;
  StreamSubscription<MapEvent>? _sub;

  final ValueNotifier<bool> _libre = ValueNotifier(false);

  /// `true` después de que el usuario movió el mapa con la mano (para mostrar
  /// el botón "Centrar"). Vuelve a `false` con el siguiente movimiento propio.
  ValueListenable<bool> get libre => _libre;

  static const _id = 'camara';

  static const _gestosDelUsuario = {
    MapEventSource.dragStart,
    MapEventSource.onDrag,
    MapEventSource.multiFingerGestureStart,
    MapEventSource.onMultiFinger,
    MapEventSource.doubleTap,
    MapEventSource.doubleTapHold,
    MapEventSource.scrollWheel,
    MapEventSource.flingAnimationController,
    MapEventSource.doubleTapZoomAnimationController,
    MapEventSource.cursorKeyboardRotation,
  };

  // --- Animación de una vez ---
  LatLng _c0 = const LatLng(0, 0), _c1 = const LatLng(0, 0);
  double _z0 = 0, _z1 = 0, _r0 = 0, _r1 = 0;
  Offset _o0 = Offset.zero, _o1 = Offset.zero;
  Curve _curva = Movimiento.enfatizada;
  Completer<bool>? _fin;

  // --- Seguimiento ---
  bool _siguiendo = false;
  LatLng? _objPos;
  double _objZoom = 18;
  double? _objRot;
  Offset _objOffset = Offset.zero;
  LatLng? _pos;
  double _zoom = 18;
  double _rot = 0;
  Offset _offset = Offset.zero;
  Duration? _ultimoTick;

  bool get siguiendo => _siguiendo;

  MapCamera? get _camara {
    try {
      return controller.camera;
    } catch (_) {
      return null; // el mapa aún no tiene tamaño
    }
  }

  /// Lleva la cámara a `centro` (que queda en el centro de la pantalla más
  /// `desplazamiento`, en píxeles). Completa con `false` si se interrumpió.
  Future<bool> animarA(
    LatLng centro, {
    double? zoom,
    double? rotacion,
    Offset desplazamiento = Offset.zero,
    Duration duracion = Movimiento.media,
    Curve curva = Movimiento.enfatizada,
  }) {
    final cam = _camara;
    if (cam == null) return Future.value(false);
    _detenerAnimacion();
    dejarDeSeguir();
    _libre.value = false;
    final z = zoom ?? cam.zoom;
    final r = rotacion ?? cam.rotation;
    if (_reducir() || duracion == Duration.zero) {
      _aplicar(centro, z, r, desplazamiento);
      return Future.value(true);
    }
    _c0 = cam.center;
    _z0 = cam.zoom;
    _r0 = cam.rotation;
    _o0 = Offset.zero;
    _c1 = centro;
    _z1 = z;
    _r1 = _r0 + _arcoCorto(_r0, r);
    _o1 = desplazamiento;
    _curva = curva;
    final fin = _fin = Completer<bool>();
    _anim
      ..duration = duracion
      ..forward(from: 0);
    return fin.future;
  }

  /// Encuadra con un `CameraFit` (rutas, campus) de forma animada.
  Future<bool> encuadrar(
    CameraFit fit, {
    Duration duracion = Movimiento.lenta,
    Curve curva = Movimiento.enfatizada,
  }) {
    final cam = _camara;
    if (cam == null) return Future.value(false);
    final destino = fit.fit(cam);
    return animarA(destino.center,
        zoom: destino.zoom,
        rotacion: cam.rotation,
        duracion: duracion,
        curva: curva);
  }

  /// Persigue un objetivo que cambia (la posición del usuario al navegar).
  /// Llamarlo con cada lectura nueva; la cámara converge suavemente.
  void seguir({
    required LatLng objetivo,
    required double zoom,
    double? rotacion,
    Offset desplazamiento = Offset.zero,
  }) {
    final cam = _camara;
    if (cam == null) return;
    if (_reducir()) {
      _aplicar(objetivo, zoom, rotacion ?? cam.rotation, desplazamiento);
      return;
    }
    if (!_siguiendo) {
      _detenerAnimacion();
      _siguiendo = true;
      _libre.value = false;
      _pos = cam.center;
      _zoom = cam.zoom;
      _rot = cam.rotation;
      _offset = Offset.zero;
    }
    _objPos = objetivo;
    _objZoom = zoom;
    _objRot = rotacion;
    _objOffset = desplazamiento;
    if (!_ticker.isActive) {
      _ultimoTick = null;
      _ticker.start();
    }
  }

  void dejarDeSeguir() {
    _siguiendo = false;
    if (_ticker.isActive) _ticker.stop();
  }

  /// Detiene cualquier movimiento en curso.
  void detener() {
    _detenerAnimacion();
    dejarDeSeguir();
  }

  void dispose() {
    _sub?.cancel();
    _completar(false);
    _anim.dispose();
    _ticker.dispose();
    _libre.dispose();
  }

  // ---------------------------------------------------------------------

  void _alEvento(MapEvent e) {
    if (_gestosDelUsuario.contains(e.source)) {
      detener();
      _libre.value = true;
    }
  }

  void _tickAnimacion() {
    final t = _curva.transform(_anim.value);
    final c = LatLng(
      _c0.latitude + (_c1.latitude - _c0.latitude) * t,
      _c0.longitude + (_c1.longitude - _c0.longitude) * t,
    );
    final z = _z0 + (_z1 - _z0) * t;
    final r = _r0 + (_r1 - _r0) * t;
    final o = Offset.lerp(_o0, _o1, t)!;
    _aplicar(c, z, r, o);
  }

  void _tickSeguimiento(Duration ahora) {
    final objetivo = _objPos;
    final pos = _pos;
    if (!_siguiendo || objetivo == null || pos == null) return;
    final previo = _ultimoTick;
    _ultimoTick = ahora;
    if (previo == null) return;
    final dt = (ahora - previo).inMicroseconds / 1e6;
    double mezcla(double tau) => 1 - math.exp(-dt / tau);

    final aPos = mezcla(0.35);
    final nuevaPos = LatLng(
      pos.latitude + (objetivo.latitude - pos.latitude) * aPos,
      pos.longitude + (objetivo.longitude - pos.longitude) * aPos,
    );
    final nuevoZoom = _zoom + (_objZoom - _zoom) * mezcla(0.5);
    final objRot = _objRot;
    final nuevaRot =
        objRot == null ? _rot : _rot + _arcoCorto(_rot, objRot) * mezcla(0.25);
    final nuevoOffset =
        Offset.lerp(_offset, _objOffset, mezcla(0.35)) ?? _objOffset;

    final cam = _camara;
    final quieto = cam != null &&
        _distanciaPx(cam, nuevaPos, objetivo) < 0.5 &&
        (nuevoZoom - _objZoom).abs() < 0.005 &&
        (objRot == null || _arcoCorto(nuevaRot, objRot).abs() < 0.5) &&
        (nuevoOffset - _objOffset).distance < 0.5;

    _pos = nuevaPos;
    _zoom = nuevoZoom;
    _rot = nuevaRot;
    _offset = nuevoOffset;
    _aplicar(nuevaPos, nuevoZoom, nuevaRot, nuevoOffset);
    // Ya convergió: se apaga el ticker hasta la siguiente lectura.
    if (quieto) _ticker.stop();
  }

  double _distanciaPx(MapCamera cam, LatLng a, LatLng b) {
    final pa = cam.project(a), pb = cam.project(b);
    return pa.distanceTo(pb);
  }

  void _aplicar(LatLng centro, double zoom, double rotacion, Offset offset) {
    final cam = _camara;
    if (cam == null) return;
    if ((cam.rotation - rotacion).abs() > 0.01) {
      controller.rotate(rotacion, id: _id);
    }
    controller.move(centro, zoom, offset: offset, id: _id);
  }

  void _detenerAnimacion() {
    if (_anim.isAnimating) _anim.stop();
    _completar(false);
  }

  void _completar(bool ok) {
    final f = _fin;
    _fin = null;
    if (f != null && !f.isCompleted) f.complete(ok);
  }

  static double _arcoCorto(double desde, double hacia) {
    var d = (hacia - desde) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }
}
