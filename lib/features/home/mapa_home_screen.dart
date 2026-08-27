import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_drawer.dart';
import '../../data/avisos.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../design_system/widgets.dart';
import '../../services/ubicacion_service.dart';
import '../mapa/mapa_campus.dart';
import 'home_sheet.dart';

class MapaHomeScreen extends ConsumerStatefulWidget {
  const MapaHomeScreen({super.key});

  @override
  ConsumerState<MapaHomeScreen> createState() => _MapaHomeScreenState();
}

class _MapaHomeScreenState extends ConsumerState<MapaHomeScreen> {
  final _map = MapController();
  final _sheetKey = GlobalKey<HomeSheetState>();
  LatLng? _posUsuario;
  bool _buscandoUbicacion = false;

  void _centrarEn(Lugar l) {
    _map.move(l.punto.toLatLng(), 17.6);
  }

  Future<void> _miUbicacion() async {
    setState(() => _buscandoUbicacion = true);
    final pos = await UbicacionService.instance.posicionActual();
    if (!mounted) return;
    setState(() {
      _buscandoUbicacion = false;
      _posUsuario = pos;
    });
    if (pos != null) {
      _map.move(pos, 17.5);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo obtener tu ubicación. Revisa los permisos.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final oscuro = theme.brightness == Brightness.dark;
    final dataAsync = ref.watch(campusDataProvider);
    final estilo = ref.watch(estiloMapaProvider);
    final seleccionadoId = ref.watch(lugarSeleccionadoProvider);
    final destacado = ref.watch(avisoDestacadoProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EstadoVacio(
              icono: Icons.map_outlined,
              titulo: 'No se pudo cargar el campus',
              descripcion: '$e',
            ),
          ),
        ),
        data: (data) => Stack(
          children: [
            Positioned.fill(
              child: MapaCampus(
                data: data,
                controller: _map,
                estilo: estilo,
                oscuro: oscuro,
                lugarDestacadoId: seleccionadoId,
                posicionUsuario: _posUsuario,
                onTapLugar: (l) {
                  ref.read(lugarSeleccionadoProvider.notifier).state = l.id;
                  _centrarEn(l);
                  _sheetKey.currentState?.medio();
                },
                onTapMapa: () {
                  ref.read(lugarSeleccionadoProvider.notifier).state = null;
                  ref.read(consultaBusquedaProvider.notifier).state = '';
                  FocusScope.of(context).unfocus();
                  _sheetKey.currentState?.colapsar();
                },
              ),
            ),

            // Barra superior
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(
                  children: [
                    Builder(
                      builder: (context) => BotonCircularMapa(
                        icon: Icons.menu,
                        tooltip: 'Menú',
                        onTap: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Center(
                        child: PastillaAccion(
                          label: 'Explorar el campus',
                          icon: Icons.explore_outlined,
                          onTap: () {
                            ref.read(lugarSeleccionadoProvider.notifier).state =
                                null;
                            _sheetKey.currentState?.expandir();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    BotonCircularMapa(
                      icon: Icons.badge_outlined,
                      tooltip: 'Credencialización',
                      onTap: () => context.push('/credencializacion'),
                    ),
                  ],
                ),
              ),
            ),

            // Banner de aviso destacado
            if (destacado != null)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 62,
                left: 14,
                right: 14,
                child: _BannerAviso(aviso: destacado),
              ),

            // Controles flotantes
            Positioned(
              right: 14,
              bottom: MediaQuery.sizeOf(context).height * 0.16 + 12,
              child: Column(
                children: [
                  BotonCircularMapa(
                    icon: estilo == EstiloMapa.satelite
                        ? Icons.map_outlined
                        : Icons.layers_outlined,
                    tooltip: 'Cambiar vista',
                    onTap: () => ref.read(estiloMapaProvider.notifier).state =
                        estilo == EstiloMapa.satelite
                            ? EstiloMapa.estandar
                            : EstiloMapa.satelite,
                  ),
                  const SizedBox(height: 10),
                  BotonCircularMapa(
                    icon: Icons.my_location,
                    tooltip: 'Mi ubicación',
                    cargando: _buscandoUbicacion,
                    onTap: _miUbicacion,
                  ),
                ],
              ),
            ),

            // Hoja inferior
            HomeSheet(key: _sheetKey, onLugarElegido: _centrarEn),
          ],
        ),
      ),
    );
  }
}

class _BannerAviso extends ConsumerWidget {
  const _BannerAviso({required this.aviso});
  final Aviso aviso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: aviso.categoria.color,
      borderRadius: BorderRadius.circular(14),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/notificaciones'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              Icon(aviso.categoria.icono, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(aviso.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    Text(aviso.cuerpo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: () => ref
                    .read(bannerDescartadoProvider.notifier)
                    .state = aviso.id,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
