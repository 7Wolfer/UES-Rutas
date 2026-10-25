import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../design_system/widgets.dart';

/// Hoja compacta para ocultar/mostrar categorías de pines en el mapa.
///
/// Solo ofrece las categorías que existen en el catálogo, en el orden del
/// directorio. El estado vive en `categoriasOcultasProvider` (persistido).
Future<void> mostrarFiltroCategorias(BuildContext context, CampusData data) {
  final presentes = data.lugares.map((l) => l.categoria).toSet();
  final categorias = [
    for (final c in ordenCategorias)
      if (presentes.contains(c)) c,
  ];
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _FiltroCategoriasSheet(categorias: categorias),
  );
}

class _FiltroCategoriasSheet extends ConsumerWidget {
  const _FiltroCategoriasSheet({required this.categorias});

  final List<CategoriaMapa> categorias;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ocultas = ref.watch(categoriasOcultasProvider);
    final notifier = ref.read(categoriasOcultasProvider.notifier);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Mostrar en el mapa',
                      style: theme.textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: ocultas.isEmpty ? null : notifier.mostrarTodas,
                  child: const Text('Todos'),
                ),
              ],
            ),
            Text(
              'Toca una categoría para ocultarla o volver a mostrarla.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                for (final c in categorias)
                  Semantics(
                    button: true,
                    toggled: !ocultas.contains(c),
                    label: c.etiqueta,
                    excludeSemantics: true,
                    onTap: () => notifier.alternar(c),
                    // 48 px de alto para el área de toque; la pastilla va
                    // centrada dentro.
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        widthFactor: 1,
                        child: ChipCategoria(
                          etiqueta: c.etiqueta,
                          color: c.color,
                          icono: c.icono,
                          seleccionado: !ocultas.contains(c),
                          onTap: () => notifier.alternar(c),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
