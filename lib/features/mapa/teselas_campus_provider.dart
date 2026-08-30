import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Proveedor de teselas híbrido: usa las teselas del campus empaquetadas como
/// assets (offline, instantáneas) cuando existen, y cae a la red (OpenStreetMap)
/// para zooms alejados o zonas fuera del campus.
///
/// Extiende la base [TileProvider] (no [NetworkTileProvider]) a propósito:
/// `NetworkTileProvider` no soporta cancelación, así que `supportsCancelLoading`
/// queda en `false` y flutter_map llama a [getImage]. Además `dispose()` es
/// no-op, por lo que la misma instancia se puede reusar aunque el `TileLayer` se
/// desmonte al alternar entre mapa y satélite.
class TeselasCampusProvider extends TileProvider {
  TeselasCampusProvider(this._empaquetadas, {super.headers});

  /// Claves "z_x_y" de las teselas incluidas en `assets/tiles/`.
  final Set<String> _empaquetadas;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final clave = '${coordinates.z}_${coordinates.x}_${coordinates.y}';
    if (_empaquetadas.contains(clave)) {
      return AssetImage('assets/tiles/$clave.png');
    }
    return NetworkImage(getTileUrl(coordinates, options), headers: headers);
  }
}
