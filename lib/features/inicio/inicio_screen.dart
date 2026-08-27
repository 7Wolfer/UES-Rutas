import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../data/providers.dart';
import '../../design_system/widgets.dart';

class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  static const _categoriasDestacadas = [
    CategoriaMapa.biblioteca,
    CategoriaMapa.alimentos,
    CategoriaMapa.servicios,
    CategoriaMapa.estacionamiento,
    CategoriaMapa.salud,
    CategoriaMapa.deportivo,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(campusDataProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/brand/llama_placeholder.svg',
                      width: 30,
                      height: 30,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'UES Rutas',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => context.push('/catalogo'),
                      icon: const Icon(Icons.palette_outlined),
                      tooltip: 'Sistema de diseño',
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text(
                  '¿A dónde quieres llegar en el campus?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push('/buscar'),
                  child: const AbsorbPointer(
                    child: CampoBusqueda(),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: EncabezadoSeccion('Categorías'),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categoriasDestacadas.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = _categoriasDestacadas[i];
                    return ChipCategoria(
                      etiqueta: c.etiqueta,
                      color: c.color,
                      icono: c.icono,
                      onTap: () => context.push(
                        '/buscar?q=${Uri.encodeComponent(c.etiqueta)}',
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 6),
                child: EncabezadoSeccion('Edificios'),
              ),
            ),
            data.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: EstadoVacio(
                    icono: Icons.error_outline,
                    titulo: 'No se pudo cargar el catálogo',
                    descripcion: '$e',
                  ),
                ),
              ),
              data: (campus) {
                final edificios = campus.edificios;
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverList.separated(
                    itemCount: edificios.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final e = edificios[i];
                      return TarjetaUes(
                        onTap: () => context.push('/espacio/esp_${e.id}'),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: UesBrand.vino.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                e.clave,
                                style: const TextStyle(
                                  color: UesBrand.vino,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.etiqueta,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                  Text(
                                    e.nombre,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
