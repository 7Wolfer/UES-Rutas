import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/brand.dart';
import '../../core/movimiento.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/routing.dart';
import 'capa_ruta.dart';
import 'capa_usuario.dart';
import 'teselas_campus_provider.dart';

/// Mapa real del campus UES: teselas de OpenStreetMap + capa propia
/// (perímetro, campo deportivo, edificios, pines, ruta y usuario).
///
/// Rendimiento:
/// - Las capas estáticas (teselas, perímetro, edificios) se construyen una
///   vez como widgets y se reutilizan: conservan su caché de proyección.
/// - El lugar resaltado y los pines viven en `Consumer`s para que un toque
///   no reconstruya todo el mapa.
/// - Los pines están siempre en la capa (con su `key`) y se muestran u ocultan
///   con una animación según el zoom: nada "parpadea" al acercar.
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
    this.avanceRuta,
    this.revelarRuta = true,
    this.lugarDestacadoId,
    this.usuario,
    this.onTapLugar,
    this.onTapMapa,
    this.onLongPress,
    this.paddingInferior = 0,
    this.rotarPines = false,
    this.permitirRotacion = false,
    this.capasSobreRuta = const [],
    this.capasSuperiores = const [],
  });

  final CampusData data;
  final MapController controller;
  final EstiloMapa estilo;
  final bool oscuro;
  final RutaCalculada? ruta;

  /// Metros ya recorridos de la ruta (navegación en curso).
  final double? avanceRuta;
  final bool revelarRuta;

  /// Lugar a resaltar de forma explícita (p. ej. el destino en "cómo llegar").
  /// Si es `null`, el mapa usa `lugarSeleccionadoProvider`.
  final String? lugarDestacadoId;
  final UbicacionEnMapa? usuario;
  final ValueChanged<Lugar>? onTapLugar;
  final VoidCallback? onTapMapa;
  final ValueChanged<LatLng>? onLongPress;
  final double paddingInferior;

  /// Mantener los pines derechos cuando el mapa gira (modo rumbo arriba).
  final bool rotarPines;

  /// Permite girar el mapa con dos dedos.
  final bool permitirRotacion;

  /// Capas extra entre la ruta y los pines (p. ej. el grafo en modo dev).
  final List<Widget> capasSobreRuta;

  /// Capas extra por encima de todo (marcas de navegación, depuración).
  final List<Widget> capasSuperiores;

  @override
  ConsumerState<MapaCampus> createState() => _MapaCampusState();
}

class _MapaCampusState extends ConsumerState<MapaCampus> {
  static const _pkgName = 'mx.ues.ues_rutas';

  /// Zoom máximo al que arranca la vista de campus.
  static const _zoomCampusMax = 17.0;

  /// Cuánto hay que acercar respecto al encuadre del campus para ver "todos"
  /// los pines. Por debajo se muestran solo los lugares principales.
  static const _saltoDetalle = 1.2;

  /// Categorías visibles cuando el mapa está "lejos" (vista de campus).
  static const _catsLejos = {
    CategoriaMapa.edificio,
    CategoriaMapa.biblioteca,
    CategoriaMapa.alimentos,
    CategoriaMapa.deportivo,
  };

  /// Matriz para oscurecer las teselas de OSM en modo oscuro (invertir, girar
  /// el tono 180°, bajar saturación y brillo, y entibiar hacia la paleta UES).
  static const _matrizOscura = ColorFilter.matrix(<double>[
    0.113, -0.829, -0.084, 0, 214, //
    -0.247, -0.469, -0.084, 0, 210, //
    -0.247, -0.829, 0.276, 0, 206, //
    0, 0, 0, 1, 0, //
  ]);

  double? _zoomBase;
  bool _zoomCerca = false;

  // --- Capas estáticas, memorizadas como widgets ---
  late LatLngBounds _limitesCampus;
  late Widget _capaTeselas;
  late Widget _capaPerimetro;
  late Widget _capaEdificios;
  Widget? _capaPlano;

  CampusData get data => widget.data;
  bool get oscuro => widget.oscuro;
  EstiloMapa get estilo => widget.estilo;

  late final TeselasCampusProvider _tileProvider;

  @override
  void initState() {
    super.initState();
    _tileProvider = TeselasCampusProvider(ref.read(teselasBundledProvider));
    _recalcularEstaticas();
    // El umbral de "cerca" se mide contra el encuadre del campus (no contra el
    // encuadre inicial, que en una ruta corta ya viene muy acercado).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final cam = widget.controller.camera;
        final z = CameraFit.bounds(
          bounds: _limitesCampus,
          padding: const EdgeInsets.fromLTRB(28, 96, 28, 44),
          maxZoom: _zoomCampusMax,
        ).fit(cam).zoom;
        setState(() {
          _zoomBase = z;
          _zoomCerca = cam.zoom >= _umbralDetalle;
        });
      } catch (_) {
        /* el controlador aún no está listo; se queda con el valor por defecto */
      }
    });
  }

  @override
  void didUpdateWidget(covariant MapaCampus old) {
    super.didUpdateWidget(old);
    if (!identical(old.data, widget.data) ||
        old.oscuro != widget.oscuro ||
        old.estilo != widget.estilo) {
      _recalcularEstaticas();
    }
  }

  void _recalcularEstaticas() {
    final perimetro = data.info.perimetro;
    if (perimetro.isEmpty) {
      final c = data.info.centro.toLatLng();
      _limitesCampus = LatLngBounds(
        LatLng(c.latitude - 0.003, c.longitude - 0.003),
        LatLng(c.latitude + 0.003, c.longitude + 0.003),
      );
    } else {
      _limitesCampus = LatLngBounds.fromPoints(
          [for (final p in perimetro) p.toLatLng()]);
    }

    _capaTeselas = _tiles();
    _capaPlano = estilo == EstiloMapa.plano && data.info.planoOverlay != null
        ? _planoLayer(data.info.planoOverlay!)
        : null;

    _capaPerimetro = PolygonLayer(polygons: [
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
    ]);

    // En la vista "Plano" el propio plano ya dibuja los edificios: los
    // polígonos se quedan apenas insinuados para no tapar sus letras.
    final plano = estilo == EstiloMapa.plano;
    _capaEdificios = PolygonLayer(polygons: [
      for (final l in data.lugares)
        if (l.poligono != null && l.poligono!.length >= 3)
          Polygon(
            points: l.poligono!.map((p) => p.toLatLng()).toList(),
            color: l.categoria.color
                .withValues(alpha: plano ? 0.06 : (oscuro ? 0.35 : 0.28)),
            borderColor:
                l.categoria.color.withValues(alpha: plano ? 0.45 : 0.9),
            borderStrokeWidth: 1,
          ),
    ]);
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
    final r = widget.ruta;
    if (r != null && r.puntos.length > 1) {
      return CameraFit.bounds(
        bounds:
            LatLngBounds.fromPoints(r.puntos.map((p) => p.toLatLng()).toList()),
        padding: EdgeInsets.fromLTRB(56, 56, 56, 56 + widget.paddingInferior),
        maxZoom: 18.5,
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
    final ruta = widget.ruta;
    final hayRuta = ruta != null && ruta.puntos.length > 1;

    return Semantics(
      container: true,
      label: 'Mapa del campus',
      child: FlutterMap(
        mapController: widget.controller,
        options: MapOptions(
          initialCenter: data.info.centro.toLatLng(),
          initialZoom: 16.4,
          minZoom: 13,
          maxZoom: 19.5,
          backgroundColor: bg,
          initialCameraFit: _encuadre,
          onTap: (_, __) => widget.onTapMapa?.call(),
          onLongPress: widget.onLongPress == null
              ? null
              : (_, p) => widget.onLongPress!.call(p),
          onPositionChanged: (camera, _) => _actualizarCuboZoom(camera.zoom),
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.drag |
                InteractiveFlag.flingAnimation |
                InteractiveFlag.pinchMove |
                InteractiveFlag.pinchZoom |
                InteractiveFlag.doubleTapZoom |
                InteractiveFlag.scrollWheelZoom |
                (widget.permitirRotacion ? InteractiveFlag.rotate : 0),
          ),
        ),
        children: [
          _capaTeselas,
          if (_capaPlano != null) _capaPlano!,
          _capaPerimetro,
          _capaEdificios,
          Consumer(builder: (context, ref, _) {
            final destacado = data.lugar(_watchDestacadoId(ref));
            final poly = destacado?.poligono;
            if (destacado == null || poly == null || poly.length < 3) {
              return const SizedBox.shrink();
            }
            return PolygonLayer(polygons: [
              Polygon(
                points: poly.map((p) => p.toLatLng()).toList(),
                color: destacado.categoria.color.withValues(alpha: 0.55),
                borderColor: destacado.categoria.color,
                borderStrokeWidth: 2.5,
              ),
            ]);
          }),
          if (hayRuta)
            CapaRuta(
              ruta: ruta,
              oscuro: oscuro,
              avanceM: widget.avanceRuta,
              revelar: widget.revelarRuta,
            ),
          ...widget.capasSobreRuta,
          Consumer(builder: (context, ref, _) {
            final ocultas = ref.watch(categoriasOcultasProvider);
            final destacadoId = _watchDestacadoId(ref);
            return _marcadores(context, destacadoId, ocultas);
          }),
          if (widget.usuario != null) CapaUsuario(ubicacion: widget.usuario!),
          Consumer(builder: (context, ref, _) {
            final destacado = data.lugar(_watchDestacadoId(ref));
            if (destacado == null) return const SizedBox.shrink();
            return MarkerLayer(
              rotate: widget.rotarPines,
              markers: [
                Marker(
                  key: ValueKey('sel-${destacado.id}'),
                  point: destacado.punto.toLatLng(),
                  width: 160,
                  height: _PinSeleccionado.alto,
                  alignment: _PinSeleccionado.alineacion,
                  child: _PinSeleccionado(
                    lugar: destacado,
                    onTap: () => widget.onTapLugar?.call(destacado),
                  ),
                ),
              ],
            );
          }),
          ...widget.capasSuperiores,
          _atribucion(context),
        ],
      ),
    );
  }

  /// El plano oficial georreferenciado (rotado ~9°): flutter_map lo coloca por
  /// sus tres esquinas, así que no hace falta rectificar la imagen.
  Widget _planoLayer(PlanoOverlay p) {
    return OverlayImageLayer(
      overlayImages: [
        RotatedOverlayImage(
          imageProvider: AssetImage(p.imagen),
          topLeftCorner: p.tl.toLatLng(),
          bottomLeftCorner: p.bl.toLatLng(),
          bottomRightCorner: p.br.toLatLng(),
          opacity: 0.94,
        ),
      ],
    );
  }

  Widget _tiles() {
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
    final capa = TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: _pkgName,
      maxNativeZoom: 19,
      tileProvider: _tileProvider,
    );
    // En oscuro se filtra la capa entera de una vez (no tesela por tesela).
    return oscuro ? ColorFiltered(colorFilter: _matrizOscura, child: capa) : capa;
  }

  /// `true` si el lugar debe verse aunque el mapa esté alejado.
  bool _visibleLejos(Lugar l) =>
      _catsLejos.contains(l.categoria) || l.id == 'lug_acceso_principal';

  MarkerLayer _marcadores(
    BuildContext context,
    String? destacadoId,
    Set<CategoriaMapa> ocultas,
  ) {
    return MarkerLayer(
      rotate: widget.rotarPines,
      markers: [
        for (final l in data.lugares)
          Marker(
            key: ValueKey(l.id),
            point: l.punto.toLatLng(),
            width: 44,
            height: 44,
            child: _PinLugar(
              lugar: l,
              // El resaltado se dibuja en su propia capa, por encima.
              visible: l.id != destacadoId &&
                  !ocultas.contains(l.categoria) &&
                  (_zoomCerca || _visibleLejos(l)),
              onTap: () => widget.onTapLugar?.call(l),
            ),
          ),
      ],
    );
  }

  Widget _atribucion(BuildContext context) {
    return RichAttributionWidget(
      alignment: AttributionAlignment.bottomLeft,
      showFlutterMapAttribution: false,
      attributions: [
        if (estilo == EstiloMapa.satelite)
          const TextSourceAttribution('Esri, Maxar, Earthstar Geographics')
        else ...[
          if (estilo == EstiloMapa.plano)
            const TextSourceAttribution('Plano: Universidad Estatal de Sonora'),
          const TextSourceAttribution('© OpenStreetMap contributors'),
        ],
      ],
    );
  }
}

/// Contenido del pin: la letra del plano oficial o el ícono de la categoría.
Widget _contenidoPin(Lugar lugar, {required bool grande}) {
  final clave = lugar.clave;
  if (clave == null) {
    return Icon(lugar.categoria.icono,
        color: Colors.white, size: grande ? 20 : 16);
  }
  return Center(
    child: Text(
      clave,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: (grande ? 17.0 : 13.0) - (clave.length > 1 ? 3 : 0),
        height: 1,
      ),
    ),
  );
}

class _PinLugar extends StatelessWidget {
  const _PinLugar({
    required this.lugar,
    required this.visible,
    required this.onTap,
  });

  final Lugar lugar;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duracion = Movimiento.de(context, Movimiento.rapida);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duracion,
        curve: visible ? Movimiento.entrada : Movimiento.salida,
        child: AnimatedScale(
          scale: visible ? 1 : 0.6,
          duration: duracion,
          curve: visible ? Movimiento.rebote : Movimiento.salida,
          child: Semantics(
            button: true,
            label: lugar.nombre,
            excludeSemantics: true,
            onTap: visible ? onTap : null,
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: lugar.categoria.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: _contenidoPin(lugar, grande: false),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pin del lugar seleccionado: crece desde el tamaño normal y muestra su
/// nombre. El centro del punto queda exactamente sobre la coordenada.
class _PinSeleccionado extends StatelessWidget {
  const _PinSeleccionado({required this.lugar, required this.onTap});

  final Lugar lugar;
  final VoidCallback onTap;

  static const double alto = 72;
  static const double _yCentroPunto = alto - 22; // punto de 40 px + margen

  /// Alinea el marcador para que el centro del punto caiga sobre la coordenada.
  static const Alignment alineacion =
      Alignment(0, 2 * (alto - _yCentroPunto) / alto - 1);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Movimiento.de(context, Movimiento.media),
      curve: Curves.linear,
      builder: (context, t, _) {
        final tamano = 30 + 10 * Movimiento.rebote.transform(t.clamp(0, 1));
        final etiqueta = Curves.easeOut.transform(((t - 0.2) / 0.8).clamp(0, 1));
        return Semantics(
          button: true,
          selected: true,
          label: lugar.nombre,
          excludeSemantics: true,
          onTap: onTap,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Opacity(
                  opacity: etiqueta,
                  child: Transform.translate(
                    offset: Offset(0, 6 * (1 - etiqueta)),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 156),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(
                        lugar.etiquetaCorta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textScaler: TextScaler.noScaling,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 44,
                  child: Center(
                    child: Container(
                      width: tamano,
                      height: tamano,
                      decoration: BoxDecoration(
                        color: lugar.categoria.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: lugar.categoria.color.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _contenidoPin(lugar, grande: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
