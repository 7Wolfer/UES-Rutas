import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/routing.dart';
import '../../design_system/widgets.dart';
import '../mapa/mapa_campus.dart';

class RutaScreen extends ConsumerStatefulWidget {
  const RutaScreen({
    super.key,
    required this.destinoId,
    this.origenId = 'lug_acceso_principal',
    this.accesibleInicial = false,
  });

  final String destinoId;
  final String origenId;
  final bool accesibleInicial;

  @override
  ConsumerState<RutaScreen> createState() => _RutaScreenState();
}

class _RutaScreenState extends ConsumerState<RutaScreen> {
  final _map = MapController();
  late bool _accesible = widget.accesibleInicial;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(campusDataProvider);
    final motor = ref.watch(motorRutasProvider);
    final cs = Theme.of(context).colorScheme;
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Cómo llegar')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EstadoVacio(
            icono: Icons.error_outline, titulo: 'Error', descripcion: '$e'),
        data: (campus) {
          final origen = campus.lugar(widget.origenId);
          final destino = campus.lugar(widget.destinoId);
          if (origen == null || destino == null || motor == null) {
            return const EstadoVacio(
              icono: Icons.wrong_location_outlined,
              titulo: 'No se pudo trazar la ruta',
            );
          }

          final ruta = motor.calcular(
            origen: origen,
            destino: destino,
            accesible: _accesible,
          );
          final pasos = motor.describir(ruta, origen: origen, destino: destino);

          return Column(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.4,
                child: MapaCampus(
                  data: campus,
                  controller: _map,
                  oscuro: oscuro,
                  ruta: ruta,
                  lugarDestacadoId: destino.id,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    _OrigenDestino(origen: origen, destino: destino),
                    const SizedBox(height: 14),
                    if (ruta.sinRuta)
                      const EstadoVacio(
                        icono: Icons.error_outline,
                        titulo: 'Sin ruta disponible',
                        descripcion:
                            'No hay un camino en el grafo de prueba entre estos '
                            'dos puntos.',
                      )
                    else ...[
                      Row(
                        children: [
                          _Metrica(
                            icono: Icons.straighten,
                            valor: '${ruta.distancia.round()} m',
                            etiqueta: 'Distancia',
                          ),
                          const SizedBox(width: 12),
                          _Metrica(
                            icono: Icons.schedule,
                            valor: '${ruta.duracionEstimada.inMinutes} min',
                            etiqueta: 'Caminando',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _accesible,
                        onChanged: (v) => setState(() => _accesible = v),
                        title: const Text('Ruta accesible'),
                        subtitle: Text(
                          'Evita escalones; prioriza rampas.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        secondary: const Icon(Icons.accessible),
                      ),
                      if (_accesible && ruta.usaRampa)
                        const _Aviso(
                            'Ruta sin escalones · usa rampa de acceso.'),
                      if (!_accesible && ruta.usaEscaleras)
                        const _Aviso(
                          'Esta ruta incluye un escalón. Activa "Ruta accesible" '
                          'para una alternativa.',
                        ),
                      const SizedBox(height: 16),
                      const EncabezadoSeccion('Indicaciones'),
                      const SizedBox(height: 4),
                      ..._pasos(context, pasos),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _pasos(BuildContext context, List<PasoRuta> pasos) {
    final cs = Theme.of(context).colorScheme;
    return [
      for (var i = 0; i < pasos.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(pasos[i].icono, size: 18, color: cs.primary),
                  ),
                  if (i != pasos.length - 1)
                    Container(width: 2, height: 20, color: cs.outlineVariant),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(pasos[i].texto,
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

class _OrigenDestino extends StatelessWidget {
  const _OrigenDestino({required this.origen, required this.destino});
  final Lugar origen;
  final Lugar destino;

  @override
  Widget build(BuildContext context) {
    return TarjetaUes(
      child: Column(
        children: [
          _fila(context, Icons.trip_origin, 'Desde', origen.nombre),
          const Padding(
            padding: EdgeInsets.only(left: 9),
            child: SizedBox(height: 14, child: VerticalDivider(width: 2)),
          ),
          _fila(context, Icons.place, 'Hasta', destino.nombre),
        ],
      ),
    );
  }

  Widget _fila(BuildContext context, IconData i, String label, String value) {
    return Row(
      children: [
        Icon(i, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Text('$label  ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        Expanded(
          child: Text(value,
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica(
      {required this.icono, required this.valor, required this.etiqueta});
  final IconData icono;
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: TarjetaUes(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(valor, style: Theme.of(context).textTheme.titleMedium),
            Text(etiqueta,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    )),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: cs.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSecondaryContainer,
                    )),
          ),
        ],
      ),
    );
  }
}
