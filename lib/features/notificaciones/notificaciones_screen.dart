import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/brand.dart';
import '../../data/avisos.dart';
import '../../data/providers.dart';
import '../../design_system/widgets.dart';

class NotificacionesScreen extends ConsumerWidget {
  const NotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avisosAsync = ref.watch(avisosProvider);
    final leidos = ref.watch(avisosLeidosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes de notificaciones',
            onPressed: () => context.push('/notificaciones/ajustes'),
          ),
        ],
      ),
      body: avisosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EstadoVacio(
          icono: Icons.error_outline,
          titulo: 'Error',
          descripcion: '$e',
        ),
        data: (avisos) {
          if (avisos.isEmpty) {
            return const EstadoVacio(
              icono: Icons.notifications_off_outlined,
              titulo: 'Sin avisos',
              descripcion: 'Aquí verás los avisos de la universidad.',
            );
          }
          final hayNoLeidos = avisos.any((a) => !leidos.contains(a.id));
          return Column(
            children: [
              if (hayNoLeidos)
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => ref
                        .read(avisosLeidosProvider.notifier)
                        .marcarTodos(avisos.map((a) => a.id)),
                    child: const Text('Marcar todas como leído'),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: avisos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _AvisoCard(
                    aviso: avisos[i],
                    leido: leidos.contains(avisos[i].id),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AvisoCard extends ConsumerWidget {
  const _AvisoCard({required this.aviso, required this.leido});
  final Aviso aviso;
  final bool leido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final fecha = DateFormat("d 'de' MMMM, y", 'es').format(aviso.fecha);
    final tarjeta = TarjetaUes(
      onTap: () {
        ref.read(avisosLeidosProvider.notifier).marcarLeido(aviso.id);
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) => _DetalleAviso(aviso: aviso),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: aviso.categoria.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(aviso.categoria.icono,
                        size: 13, color: aviso.categoria.color),
                    const SizedBox(width: 4),
                    Text(aviso.categoria.etiqueta,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: aviso.categoria.color,
                              fontWeight: FontWeight.w700,
                            )),
                  ],
                ),
              ),
              const Spacer(),
              Text(fecha,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      )),
              if (!leido) ...[
                const SizedBox(width: 8),
                const CircleAvatar(
                    radius: 4, backgroundColor: UesBrand.naranja),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(aviso.titulo,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: leido ? FontWeight.w600 : FontWeight.w700,
                  )),
          const SizedBox(height: 4),
          Text(aviso.cuerpo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  )),
        ],
      ),
    );
    return leido ? tarjeta : Semantics(label: 'Aviso sin leer', child: tarjeta);
  }
}

class _DetalleAviso extends StatelessWidget {
  const _DetalleAviso({required this.aviso});
  final Aviso aviso;

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat("EEEE d 'de' MMMM, y", 'es').format(aviso.fecha);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fecha,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
            const SizedBox(height: 8),
            Text(aviso.titulo,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(aviso.cuerpo, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
