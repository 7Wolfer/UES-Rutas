import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/brand.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/routing.dart';

/// Mapa real del campus UES: teselas de OpenStreetMap + capa propia
/// (perímetro, campo deportivo, edificios, pines y ruta).
///
/// Nota web: en la build web con CanvasKit, las teselas de `flutter_map` no
/// empiezan a cargarse hasta el primer gesto real (toque/scroll). En iOS y
/// Android (los objetivos de la app) cargan normalmente.
class MapaCampus extends StatefulWidget {
  const MapaCampus({
    super.key,
    required this.data,
    required this.controller,
    this.estilo = EstiloMapa.estandar,
    this.oscuro = false,
    this.ruta,
    this.lugarDestacadoId,
    this.posicionUsuario,
    this.onTapLugar,
    this.onTapMapa,
    this.paddingInferior = 0,
  });

  final CampusData data;
  final MapController controller;
  final EstiloMapa estilo;
  final bool oscuro;
  final RutaCalculada? ruta;
  final String? lugarDestacadoId;
  final LatLng? posicionUsuario;
  final ValueChanged<Lugar>? onTapLugar;
  final VoidCallback? onTapMapa;
  final double paddingInferior;

  @override
  State<MapaCampus> createState() => _MapaCampusState();
}

class _MapaCampusState extends State<MapaCampus> {
  static const _pkgName = 'mx.ues.ues_rutas';

  CampusData get data => widget.data;
  bool get oscuro => widget.oscuro;
  EstiloMapa get estilo => widget.estilo;
  RutaCalculada? get ruta => widget.ruta;
  String? get lugarDestacadoId => widget.lugarDestacadoId;

  LatLngBounds get _limitesCampus {
    final lats = data.info.perimetro.map((p) => p.lat).toList();
    final lngs = data.info.perimetro.map((p) => p.lng).toList();
    return LatLngBounds(
      LatLng(lats.reduce((a, b) => a < b ? a : b),
          lngs.reduce((a, b) => a < b ? a : b)),
      LatLng(lats.reduce((a, b) => a > b ? a : b),
          lngs.reduce((a, b) => a > b ? a : b)),
    );
  }

  CameraFit get _encuadre {
    final r = ruta;
    if (r != null && r.puntos.length > 1) {
      return CameraFit.bounds(
        bounds:
            LatLngBounds.fromPoints(r.puntos.map((p) => p.toLatLng()).toList()),
        padding: const EdgeInsets.all(56),
      );
    }
    return CameraFit.bounds(
      bounds: _limitesCampus,
      padding: EdgeInsets.fromLTRB(28, 96, 28, 44 + widget.paddingInferior),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = oscuro ? const Color(0xFF16130F) : const Color(0xFFF2EFEA);

    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        initialCenter: data.info.centro.toLatLng(),
        initialZoom: 16.4,
        minZoom: 13,
        maxZoom: 19,
        backgroundColor: bg,
        initialCameraFit: _encuadre,
        onTap: (_, __) => widget.onTapMapa?.call(),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.drag |
              InteractiveFlag.flingAnimation |
              InteractiveFlag.pinchMove |
              InteractiveFlag.pinchZoom |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.scrollWheelZoom,
        ),
      ),
      children: [
        _tiles(),
        _perimetro(),
        _edificios(context),
        if (ruta != null && ruta!.puntos.length > 1) _rutaLayer(),
        _marcadores(context),
        _atribucion(context),
      ],
    );
  }

  TileLayer _tiles() {
    if (estilo == EstiloMapa.satelite) {
      return TileLayer(
        urlTemplate:
            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName: _pkgName,
        maxNativeZoom: 19,
      );
    }
    // OSM estándar, un solo host (bueno para CSP y política de uso).
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: _pkgName,
      maxNativeZoom: 19,
    );
  }

  PolygonLayer _perimetro() {
    return PolygonLayer(
      polygons: [
        Polygon(
          points: data.info.perimetro.map((p) => p.toLatLng()).toList(),
          color: UesBrand.naranja.withValues(alpha: oscuro ? 0.10 : 0.07),
          borderColor: UesBrand.naranja.withValues(alpha: 0.55),
          borderStrokeWidth: 2,
        ),
        if (data.info.campoDeportivo.length > 2)
          Polygon(
            points: data.info.campoDeportivo.map((p) => p.toLatLng()).toList(),
            color: const Color(0xFF3E8E4F).withValues(alpha: 0.18),
            borderColor: const Color(0xFF3E8E4F).withValues(alpha: 0.5),
            borderStrokeWidth: 1,
          ),
      ],
    );
  }

  PolygonLayer _edificios(BuildContext context) {
    final polis = <Polygon>[];
    for (final l in data.lugares) {
      final poly = l.poligono;
      if (poly == null || poly.length < 3) continue;
      final destacado = l.id == lugarDestacadoId;
      polis.add(Polygon(
        points: poly.map((p) => p.toLatLng()).toList(),
        color: l.categoria.color
            .withValues(alpha: destacado ? 0.55 : (oscuro ? 0.35 : 0.28)),
        borderColor: l.categoria.color.withValues(alpha: 0.9),
        borderStrokeWidth: destacado ? 2.5 : 1,
      ));
    }
    return PolygonLayer(polygons: polis);
  }

  PolylineLayer _rutaLayer() {
    final pts = ruta!.puntos.map((p) => p.toLatLng()).toList();
    return PolylineLayer(
      polylines: [
        Polyline(
          points: pts,
          strokeWidth: 8,
          color: Colors.white.withValues(alpha: oscuro ? 0.25 : 0.9),
        ),
        Polyline(points: pts, strokeWidth: 4.5, color: UesBrand.naranja),
      ],
    );
  }

  MarkerLayer _marcadores(BuildContext context) {
    final markers = <Marker>[];

    for (final l in data.lugares) {
      final destacado = l.id == lugarDestacadoId;
      markers.add(Marker(
        point: l.punto.toLatLng(),
        width: destacado ? 150 : 34,
        height: destacado ? 62 : 34,
        alignment: Alignment.center,
        child: _PinLugar(
          lugar: l,
          destacado: destacado,
          onTap: () => widget.onTapLugar?.call(l),
        ),
      ));
    }

    if (ruta != null && ruta!.puntos.length > 1) {
      markers.add(Marker(
        point: ruta!.puntos.first.toLatLng(),
        width: 26,
        height: 26,
        child:
            const _PuntoRuta(color: UesBrand.exito, icono: Icons.trip_origin),
      ));
    }

    if (widget.posicionUsuario != null) {
      markers.add(Marker(
        point: widget.posicionUsuario!,
        width: 26,
        height: 26,
        child: const _PuntoUsuario(),
      ));
    }

    return MarkerLayer(markers: markers);
  }

  Widget _atribucion(BuildContext context) {
    return RichAttributionWidget(
      alignment: AttributionAlignment.bottomLeft,
      showFlutterMapAttribution: false,
      attributions: [
        if (estilo == EstiloMapa.satelite)
          const TextSourceAttribution('Esri, Maxar, Earthstar Geographics')
        else
          const TextSourceAttribution('© OpenStreetMap contributors'),
      ],
    );
  }
}

class _PinLugar extends StatelessWidget {
  const _PinLugar({
    required this.lugar,
    required this.destacado,
    required this.onTap,
  });

  final Lugar lugar;
  final bool destacado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final punto = Container(
      width: destacado ? 40 : 30,
      height: destacado ? 40 : 30,
      decoration: BoxDecoration(
        color: lugar.categoria.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: destacado ? 3 : 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(lugar.categoria.icono,
          color: Colors.white, size: destacado ? 20 : 16),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: destacado
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4)
                    ],
                  ),
                  child: Text(
                    lugar.etiquetaCorta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 3),
                punto,
              ],
            )
          : punto,
    );
  }
}

class _PuntoRuta extends StatelessWidget {
  const _PuntoRuta({required this.color, required this.icono});
  final Color color;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Icon(icono, color: Colors.white, size: 12),
    );
  }
}

class _PuntoUsuario extends StatelessWidget {
  const _PuntoUsuario();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: const Color(0xFF1A73E8),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
