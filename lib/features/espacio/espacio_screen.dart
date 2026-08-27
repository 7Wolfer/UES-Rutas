import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../design_system/widgets.dart';
import '../mapa/mapa_campus.dart';

class EspacioScreen extends ConsumerWidget {
  const EspacioScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(campusDataProvider);
    final cs = Theme.of(context).colorScheme;

    return data.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EstadoVacio(
          icono: Icons.error_outline,
          titulo: 'Error',
          descripcion: '$e',
        ),
      ),
      data: (campus) {
        final e = campus.espacio(id);
        if (e == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EstadoVacio(
              icono: Icons.help_outline,
              titulo: 'Espacio no encontrado',
            ),
          );
        }
        final edificio = campus.edificio(e.edificioId);
        final cat = e.categoria;
        final esEdificio = e.tipo == TipoEspacio.edificio;

        final docentesAqui = campus.docentes
            .where((d) => d.asignaciones.any((a) {
                  final esp = campus.espacio(a.espacioId);
                  if (esp == null) return false;
                  if (esEdificio) return esp.edificioId == edificio?.id;
                  return a.espacioId == e.id;
                }))
            .toList();

        final espaciosEnEdificio = esEdificio
            ? (campus.espacios
                .where((x) =>
                    x.edificioId == edificio?.id && x.tipo != TipoEspacio.edificio)
                .toList()
              ..sort((a, b) => a.nivel.compareTo(b.nivel)))
            : <Espacio>[];

        return Scaffold(
          appBar: AppBar(title: Text(e.titulo)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(cat.icono, color: cat.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.titulo,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (edificio != null) edificio.etiqueta,
                            if (e.edificioId != null) etiquetaNivel(e.nivel),
                            if (edificio == null) cat.etiqueta,
                          ].join('  ·  '),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (e.accesible) const PastillaAccesible(),
              if (e.descripcion.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(e.descripcion,
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.push('/ruta?destino=${e.id}'),
                icon: const Icon(Icons.directions_walk),
                label: const Text('Cómo llegar'),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 200,
                  child: IgnorePointer(
                    child: MapaCampus(
                      data: campus,
                      destacarEspacioId: e.id,
                      nivelInicial: e.nivel,
                      mostrarSelectorNivel: false,
                    ),
                  ),
                ),
              ),
              if (espaciosEnEdificio.isNotEmpty) ...[
                const SizedBox(height: 24),
                const EncabezadoSeccion('En este edificio'),
                ..._porNivel(context, campus, espaciosEnEdificio),
              ],
              if (docentesAqui.isNotEmpty) ...[
                const SizedBox(height: 24),
                const EncabezadoSeccion('Docentes con clase aquí'),
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

  List<Widget> _porNivel(
      BuildContext context, CampusData campus, List<Espacio> espacios) {
    final niveles = espacios.map((e) => e.nivel).toSet().toList()..sort();
    return [
      for (final n in niveles) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            etiquetaNivel(n),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        ...espacios.where((e) => e.nivel == n).map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(e.categoria.icono, color: e.categoria.color),
                title: Text(e.titulo),
                trailing: e.accesible
                    ? const PastillaAccesible(compacta: true)
                    : null,
                onTap: () => context.push('/espacio/${e.id}'),
              ),
            ),
      ],
    ];
  }
}
