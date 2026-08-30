import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/compartir.dart';
import '../../data/providers.dart';
import '../../design_system/widgets.dart';
import '../mapa/mapa_campus.dart';

/// Ficha de un lugar del campus (edificio, servicio, acceso).
class EspacioScreen extends ConsumerWidget {
  const EspacioScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(campusDataProvider);
    final cs = Theme.of(context).colorScheme;

    return data.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EstadoVacio(
            icono: Icons.error_outline, titulo: 'Error', descripcion: '$e'),
      ),
      data: (campus) {
        final l = campus.lugar(id);
        if (l == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EstadoVacio(
                icono: Icons.help_outline, titulo: 'Lugar no encontrado'),
          );
        }

        final docentesAqui = campus.docentes
            .where((d) =>
                d.asignaciones.any((a) => a.lugarId == l.id) ||
                d.oficinaLugarId == l.id)
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(l.nombre),
            actions: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'Compartir',
                  onPressed: () => compartir(
                    context,
                    titulo: '${l.nombre} — UES Rutas',
                    ruta: '/espacio/${l.id}',
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: l.categoria.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(l.categoria.icono, color: l.categoria.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.nombre,
                            style: Theme.of(context).textTheme.headlineSmall),
                        Text(l.categoria.etiqueta,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (l.accesible) const PastillaAccesible(),
              if (l.descripcion.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l.descripcion,
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.push('/ruta?destino=${l.id}'),
                icon: const Icon(Icons.directions_walk),
                label: const Text('Cómo llegar'),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 220,
                  child: IgnorePointer(
                    child: MapaCampus(
                      data: campus,
                      controller: MapController(),
                      oscuro: Theme.of(context).brightness == Brightness.dark,
                      lugarDestacadoId: l.id,
                    ),
                  ),
                ),
              ),
              if (docentesAqui.isNotEmpty) ...[
                const SizedBox(height: 24),
                const EncabezadoSeccion('Docentes en este lugar'),
                const SizedBox(height: 4),
                ...docentesAqui.map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TarjetaUes(
                      onTap: () => context.push('/docente/${d.id}'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          AvatarDocente(iniciales: d.iniciales, radio: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.nombre,
                                    style:
                                        Theme.of(context).textTheme.titleSmall),
                                Text(d.departamento,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
