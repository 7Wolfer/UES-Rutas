import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../core/compartir.dart';
import '../../data/busqueda.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../design_system/widgets.dart';

class HomeSheet extends ConsumerStatefulWidget {
  const HomeSheet({super.key, required this.onLugarElegido});

  /// Se llama cuando el usuario elige un lugar (para centrar el mapa).
  final ValueChanged<Lugar> onLugarElegido;

  @override
  ConsumerState<HomeSheet> createState() => HomeSheetState();
}

class HomeSheetState extends ConsumerState<HomeSheet> {
  final _sheet = DraggableScrollableController();
  final _buscar = TextEditingController();
  Timer? _debounce;

  static const _colapsado = 0.18;
  static const _medio = 0.48;
  static const _expandido = 0.92;

  void expandir() => _animar(_expandido);
  void colapsar() => _animar(_colapsado);
  void medio() => _animar(_medio);

  void _animar(double size) {
    if (!_sheet.isAttached) return;
    if ((_sheet.size - size).abs() < 0.02) return; // ya está ahí
    if (mounted && MediaQuery.disableAnimationsOf(context)) {
      _sheet.jumpTo(size);
      return;
    }
    _sheet.animateTo(size,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic);
  }

  void _alBuscar(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      ref.read(consultaBusquedaProvider.notifier).state = '';
      return;
    }
    ref.read(lugarSeleccionadoProvider.notifier).state = null;
    expandir();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) ref.read(consultaBusquedaProvider.notifier).state = v;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sheet.dispose();
    _buscar.dispose();
    super.dispose();
  }

  void _elegir(Lugar l) {
    ref.read(lugarSeleccionadoProvider.notifier).state = l.id;
    widget.onLugarElegido(l);
    FocusScope.of(context).unfocus();
    medio();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final seleccionadoId = ref.watch(lugarSeleccionadoProvider);
    final consulta = ref.watch(consultaBusquedaProvider);
    final data = ref.watch(campusDataProvider).valueOrNull;
    final seleccionado = data?.lugar(seleccionadoId);

    // Sincroniza el texto si se limpió desde fuera.
    if (consulta.isEmpty && _buscar.text.isNotEmpty) _buscar.clear();

    return DraggableScrollableSheet(
      controller: _sheet,
      initialChildSize: _colapsado,
      minChildSize: _colapsado,
      maxChildSize: _expandido,
      snap: true,
      snapSizes: const [_colapsado, _medio, _expandido],
      builder: (context, scrollController) {
        return Material(
          color: cs.surface,
          elevation: 12,
          shadowColor: Colors.black38,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const HandleHoja(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: CampoBusqueda(
                  controller: _buscar,
                  hintText: '¿A dónde vas en el campus?',
                  onChanged: _alBuscar,
                ),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              Expanded(
                child: seleccionado != null
                    ? _FichaLugar(
                        lugar: seleccionado,
                        scrollController: scrollController,
                      )
                    : consulta.trim().isNotEmpty
                        ? _Resultados(
                            scrollController: scrollController,
                            onElegir: _elegir)
                        : _Directorio(
                            scrollController: scrollController,
                            onElegir: _elegir,
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FichaLugar extends ConsumerWidget {
  const _FichaLugar({required this.lugar, required this.scrollController});
  final Lugar lugar;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: lugar.categoria.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(lugar.categoria.icono, color: lugar.categoria.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lugar.nombre,
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(lugar.categoria.etiqueta,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          )),
                ],
              ),
            ),
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: 'Compartir',
                onPressed: () => compartir(
                  context,
                  titulo: '${lugar.nombre} — UES Rutas',
                  ruta: '/espacio/${lugar.id}',
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cerrar',
              onPressed: () =>
                  ref.read(lugarSeleccionadoProvider.notifier).state = null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (lugar.accesible) const PastillaAccesible(),
        if (lugar.descripcion.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(lugar.descripcion, style: Theme.of(context).textTheme.bodyLarge),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push('/ruta?destino=${lugar.id}'),
                icon: const Icon(Icons.directions_walk),
                label: const Text('Cómo llegar'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => context.push('/espacio/${lugar.id}'),
              child: const Text('Ficha'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Resultados extends ConsumerWidget {
  const _Resultados({required this.scrollController, required this.onElegir});
  final ScrollController scrollController;
  final ValueChanged<Lugar> onElegir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultados = ref.watch(resultadosBusquedaProvider);
    final data = ref.watch(campusDataProvider).valueOrNull;
    if (resultados.isEmpty) {
      return const EstadoVacio(
        icono: Icons.search_off,
        titulo: 'Sin resultados',
        descripcion: 'Prueba con otro término.',
      );
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: resultados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final r = resultados[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: r.color.withValues(alpha: 0.14),
            child: Icon(r.icono, color: r.color, size: 20),
          ),
          title: Text(r.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(r.subtitulo),
          onTap: () {
            if (r.tipo == TipoResultado.docente) {
              context.push('/docente/${r.id}');
            } else {
              final l = data?.lugar(r.id);
              if (l != null) onElegir(l);
            }
          },
        );
      },
    );
  }
}

class _Directorio extends ConsumerWidget {
  const _Directorio({required this.scrollController, required this.onElegir});
  final ScrollController scrollController;
  final ValueChanged<Lugar> onElegir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(directorioProvider);
    if (items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final cs = Theme.of(context).colorScheme;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: items.length + 1,
      itemBuilder: (context, i) {
        if (i == items.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: Text('Datos de prueba · el catálogo real llega después',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ),
          );
        }
        final it = items[i];
        if (it is CategoriaMapa) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Row(
              children: [
                Icon(it.icono, size: 18, color: it.color),
                const SizedBox(width: 8),
                Text(it.etiqueta.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                        )),
              ],
            ),
          );
        }
        final l = it as Lugar;
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: l.categoria.color, shape: BoxShape.circle),
          ),
          title: Text(l.nombre),
          trailing: l.accesible
              ? const Icon(Icons.accessible, size: 16, color: Color(0xFF2457A6))
              : null,
          onTap: () => onElegir(l),
        );
      },
    );
  }
}
