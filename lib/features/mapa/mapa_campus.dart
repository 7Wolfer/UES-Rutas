import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/brand.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/routing.dart';
import 'teselas_campus_provider.dart';

/// Mapa real del campus UES: teselas de OpenStreetMap + capa propia
/// (perímetro, campo deportivo, edificios, pines y ruta).
///
/// Rendimiento:
/// - Las capas estáticas (teselas, perímetro, contorno de edificios) se
///   construyen una sola vez; solo se rehacen si cambian `data`/`estilo`/`oscuro`.
/// - El lugar resaltado y los marcadores viven en un `Consumer` para que un
///   toque en un pin no reconstruya todo el mapa.
/// - Los marcadores se filtran por zoom: pocos de lejos, todos de cerca.
///
/// Las teselas del área del campus van empaquetadas como assets
/// (`TeselasCampusProvider`): el mapa carga al instante y sin red. Fuera del
/// campus o a zooms muy alejados se sigue pidiendo a OpenStreetMap.
class MapaCampus extends ConsumerStatefulWidget {
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

  /// Lugar a resaltar de forma explícita (p. ej. el destino en "cómo llegar").
  /// Si es `null`, el mapa usa `lugarSeleccionadoProvider`.
  final String? lugarDestacadoId;
  final LatLng? posicionUsuario;
  final ValueChanged<Lugar>? onTapLugar;
  final VoidCallback? onTapMapa;
  final double paddingInferior;

  @override
  ConsumerState<MapaCampus> createState() => _MapaCampusState();
}

class _MapaCampusState extends ConsumerState<MapaCampus> {
  static const _pkgName = 'mx.ues.ues_rutas';

  /// Zoom máximo al que arranca la vista de campus (mismo encuadre en móvil y
  /// escritorio, para que el zoom-gate de pines sea consistente).
  static const _zoomCampusMax = 17.0;

  /// Cuánto hay que acercar respecto al encuadre inicial para ver "todos" los
  /// pines. Por debajo se muestran solo los lugares principales.
  static const _saltoDetalle = 1.2;

  /// Categorías visibles cuando el mapa está "lejos" (vista de campus).
  static const _catsLejos = {
    CategoriaMapa.aula,
    CategoriaMapa.biblioteca,
    CategoriaMapa.alimentos,
    CategoriaMapa.deportivo,
  };

  double? _zoomBase;
  bool _zoomCerca = false;

  // --- Capas estáticas, memorizadas ---
  late LatLngBounds _limitesCampus;
  late List<Polygon> _perimetroPolis;
  late List<Polygon> _edificiosBasePolis;

  CampusData get data => widget.data;
  bool get oscuro => widget.oscuro;
  EstiloMapa get estilo => widget.estilo;
  RutaCalculada? get ruta => widget.ruta;

  late final TeselasCampusProvider _tileProvider;

  @override
  void initState() {
    super.initState();
    _tileProvider = TeselasCampusProvider(ref.read(teselasBundledProvider));
    _recalcularEstaticas();
    // El zoom real del encuadre inicial (ya aplicado el `initialCameraFit`).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final z = widget.controller.camera.zoom;
        if (_zoomBase != z) setState(() => _zoomBase = z);
      } catch (_) {
        /* el controlador aún no está listo; se queda con el valor por defecto */
      }
    });
  }

  @override
  void didUpdateWidget(covariant MapaCampus old) {
    super.didUpdateWidget(old);
    if (!identical(old.data, widget.data) || old.oscuro != widget.oscuro) {
      _recalcularEstaticas();
    }
  }

  void _recalcularEstaticas() {
    final lats = data.info.perimetro.map((p) => p.lat).toList();
    final lngs = data.info.perimetro.map((p) => p.lng).toList();
    _limitesCampus = LatLngBounds(
      LatLng(lats.reduce((a, b) => a < b ? a : b),
          lngs.reduce((a, b) => a < b ? a : b)),
      LatLng(lats.reduce((a, b) => a > b ? a : b),
          lngs.reduce((a, b) => a > b ? a : b)),
    );

    _perimetroPolis = [
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
    ];

    _edificiosBasePolis = [
      for (final l in data.lugares)
        if (l.poligono != null && l.poligono!.length >= 3)
          Polygon(
            points: l.poligono!.map((p) => p.toLatLng()).toList(),
            color: l.categoria.color.withValues(alpha: oscuro ? 0.35 : 0.28),
            borderColor: l.categoria.color.withValues(alpha: 0.9),
            borderStrokeWidth: 1,
          ),
    ];
  }

  double get _umbralDetalle => (_zoomBase ?? 16.5) + _saltoDetalle;

  /// Cambia el "cubo" de zoom (lejos/cerca) solo cuando cruza el umbral, y
  /// nunca durante la fase de build (el `initialCameraFit` puede dispararlo).
  void _actualizarCuboZoom(double zoom) {
    final cerca = zoom >= _umbralDetalle;
    if (cerca == _zoomCerca || !mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (zoom >= _umbralDetalle) != _zoomCerca) {
          setState(() => _zoomCerca = zoom >= _umbralDetalle);
        }
      });
    } else {
      setState(() => _zoomCerca = cerca);
    }
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
      maxZoom: _zoomCampusMax,
    );
  }

  /// Id del lugar a resaltar: el explícito o, si no, el seleccionado en la app.
  String? _watchDestacadoId(WidgetRef ref) =>
      widget.lugarDestacadoId ?? ref.watch(lugarSeleccionadoProvider);

  @override
  Widget build(BuildContext context) {
    final bg = oscuro ? const Color(0xFF16130F) : const Color(0xFFF2EFEA);
    final hayRuta = ruta != null && ruta!.puntos.length > 1;

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
        onPositionChanged: (camera, _) => _actualizarCuboZoom(camera.zoom),
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
        PolygonLayer(polygons: _perimetroPolis),
        PolygonLayer(polygons: _edificiosBasePolis),
        Consumer(builder: (context, ref, _) {
          final destacado = data.lugar(_watchDestacadoId(ref));
          final poly = destacado?.poligono;
          if (poly == null || poly.length < 3) {
            return const SizedBox.shrink();
          }
          return PolygonLayer(polygons: [
            Polygon(
              points: poly.map((p) => p.toLatLng()).toList(),
              color: destacado!.categoria.color.withValues(alpha: 0.55),
              borderColor: destacado.categoria.color,
              borderStrokeWidth: 2.5,
            ),
          ]);
        }),
        if (hayRuta) _rutaLayer(),
        Consumer(builder: (context, ref, _) {
          return _marcadores(context, _watchDestacadoId(ref));
        }),
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
    // OSM estándar: el área del campus sale de los assets empaquetados; el resto
    // (y otros zooms) se pide a este host, único, por red.
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: _pkgName,
      maxNativeZoom: 19,
      tileProvider: _tileProvider,
    );
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

  /// `true` si el lugar debe verse aunque el mapa esté alejado (vista de campus).
  bool _visibleLejos(Lugar l) =>
      _catsLejos.contains(l.categoria) || l.id == 'lug_acceso_principal';

  MarkerLayer _marcadores(BuildContext context, String? destacadoId) {
    final markers = <Marker>[];

    for (final l in data.lugares) {
      final destacado = l.id == destacadoId;
      if (!_zoomCerca && !destacado && !_visibleLejos(l)) continue;
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
        border: Border.all(color: Colors.white, width: destacado ? 3 : 2.5),
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
                    border: Border.all(color: cs.outlineVariant),
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
