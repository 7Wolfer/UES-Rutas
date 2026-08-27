import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Ubicación del usuario. Si el permiso se niega o falla, devuelve `null` y la
/// app hace fallback al centro del campus.
class UbicacionService {
  UbicacionService._();
  static final UbicacionService instance = UbicacionService._();

  Future<LatLng?> posicionActual() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}
