import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/compartir.dart';
import '../../core/formato.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../design_system/widgets.dart';

class DocenteScreen extends ConsumerWidget {
  const DocenteScreen({super.key, required this.id});

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
        final d = campus.docente(id);
        if (d == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EstadoVacio(
                icono: Icons.person_off_outlined,
                titulo: 'Docente no encontrado'),
          );
        }
        final oficina = campus.lugar(d.oficinaLugarId);
        final porDia = <int, List<Asignacion>>{};
        for (final a in d.asignaciones) {
          porDia.putIfAbsent(a.dia, () => []).add(a);
        }
        final dias = porDia.keys.toList()..sort();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Docente'),
            actions: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'Compartir',
                  onPressed: () => compartir(
                    context,
                    titulo: '${d.nombre} — UES Rutas',
                    ruta: '/docente/${d.id}',
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
                  AvatarDocente(iniciales: d.iniciales, radio: 30),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.nombre,
                            style: Theme.of(context).textTheme.headlineSmall),
                        Text(d.departamento,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (d.correo.isNotEmpty)
                _FilaInfo(icono: Icons.mail_outline, texto: d.correo),
              if (oficina != null)
                _FilaInfo(
                  icono: Icons.meeting_room_outlined,
                  texto: 'Oficina · ${oficina.nombre}',
                  onTap: () => context.push('/espacio/${oficina.id}'),
                ),
              const SizedBox(height: 20),
              const EncabezadoSeccion('Horario de clases'),
              if (dias.isEmpty)
                Text('Sin asignaciones registradas.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        )),
              for (final dia in dias) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 6),
                  child: Text(
                    diasSemana[dia - 1],
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: cs.secondary),
                  ),
                ),
                ...(porDia[dia]!
                      ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio)))
                    .map((a) => _FilaClase(
                          asignacion: a,
                          lugar: campus.lugar(a.lugarId),
                        )),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FilaInfo extends StatelessWidget {
  const _FilaInfo({required this.icono, required this.texto, this.onTap});

  final IconData icono;
  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icono,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
                child:
                    Text(texto, style: Theme.of(context).textTheme.bodyMedium)),
            if (onTap != null) const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _FilaClase extends StatelessWidget {
  const _FilaClase({required this.asignacion, required this.lugar});

  final Asignacion asignacion;
  final Lugar? lugar;

  @override
  Widget build(BuildContext context) {
    final a = asignacion;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TarjetaUes(
        onTap:
            lugar == null ? null : () => context.push('/espacio/${lugar!.id}'),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${a.materia}  ·  ${a.grupo}',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                Text(a.horario,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                        )),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.place_outlined,
                    size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    lugar?.nombre ?? 'Lugar por definir',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ),
                if (lugar != null)
                  TextButton.icon(
                    onPressed: () => context.push('/ruta?destino=${lugar!.id}'),
                    icon: const Icon(Icons.directions_walk, size: 18),
                    label: const Text('Ir'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
