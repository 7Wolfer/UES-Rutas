import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Por qué no se pudo obtener la ubicación (o `ok` si sí se pudo).
enum EstadoUbicacion {
  ok,
  servicioApagado,
  permisoDenegado,
  permisoBloqueado,
  error,
}

@immutable
class UbicacionResultado {
  const UbicacionResultado(this.estado, [this.posicion]);

  final EstadoUbicacion estado;
  final LatLng? posicion;

  bool get exito => estado == EstadoUbicacion.ok && posicion != null;
}

/// Acceso a la ubicación del dispositivo. El permiso del sistema se pide solo
/// dentro de [localizar], y únicamente cuando la UI llama a ese método a raíz de
/// una acción del usuario.
class UbicacionService {
  UbicacionService._();
  static final UbicacionService instance = UbicacionService._();

  /// Comprueba si ya hay permiso sin abrir ningún diálogo. Sirve para decidir el
  /// origen por defecto de una ruta sin molestar al usuario.
  Future<bool> permisoConcedido() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.always ||
          p == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  /// Pide permiso si hace falta (dispara el diálogo del sistema) y devuelve la
  /// posición actual, o el motivo del fallo. Con tope de tiempo para que la UI
  /// nunca se quede colgada si el usuario ignora el diálogo del navegador.
  Future<UbicacionResultado> localizar() async {
    try {
      return await _localizar().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      return const UbicacionResultado(EstadoUbicacion.error);
    } catch (_) {
      return const UbicacionResultado(EstadoUbicacion.error);
    }
  }

  Future<UbicacionResultado> _localizar() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const UbicacionResultado(EstadoUbicacion.servicioApagado);
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.deniedForever) {
      return const UbicacionResultado(EstadoUbicacion.permisoBloqueado);
    }
    if (permiso == LocationPermission.denied) {
      return const UbicacionResultado(EstadoUbicacion.permisoDenegado);
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return UbicacionResultado(
      EstadoUbicacion.ok,
      LatLng(p.latitude, p.longitude),
    );
  }

  /// Ajustes de la app (para reactivar un permiso bloqueado). No disponible en web.
  Future<bool> abrirAjustesApp() async {
    if (kIsWeb) return false;
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Ajustes de ubicación del sistema (para encender el servicio). No en web.
  Future<bool> abrirAjustesUbicacion() async {
    if (kIsWeb) return false;
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }
}
