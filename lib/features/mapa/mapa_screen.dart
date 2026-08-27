import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../data/providers.dart';
import '../../design_system/widgets.dart';
import 'mapa_campus.dart';

class MapaScreen extends ConsumerWidget {
  const MapaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(campusDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa del campus'),
        actions: [
          IconButton(
            onPressed: () => context.push('/buscar'),
            icon: const Icon(Icons.search),
            tooltip: 'Buscar',
          ),
          IconButton(
            onPressed: () => _mostrarLeyenda(context),
            icon: const Icon(Icons.info_outline),
            tooltip: 'Leyenda',
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EstadoVacio(
          icono: Icons.error_outline,
          titulo: 'No se pudo cargar el mapa',
          descripcion: '$e',
        ),
        data: (campus) => MapaCampus(
          data: campus,
          onTapEspacio: (e) => context.push('/espacio/${e.id}'),
        ),
      ),
    );
  }

  void _mostrarLeyenda(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Leyenda del mapa',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Colores de categoría — extensión digital, pendiente de validar '
                'con Difusión e Imagen Institucional.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in CategoriaMapa.values)
                    ChipCategoria(
                      etiqueta: c.etiqueta,
                      color: c.color,
                      icono: c.icono,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.circle, size: 14, color: UesBrand.naranja),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Tu ubicación (simulada en la demo)',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
