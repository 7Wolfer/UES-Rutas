import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/notificaciones_service.dart';
import '../ajustes/settings_controller.dart';

class NotificacionesAjustesScreen extends ConsumerWidget {
  const NotificacionesAjustesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes de notificaciones')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: s.notificaciones,
            onChanged: (v) async {
              await ctrl.setNotificaciones(v);
              if (v) await NotificacionesService.instance.pedirPermiso();
            },
            title: const Text('Notificaciones en este dispositivo'),
            subtitle: const Text(
                'Recibe un aviso local cuando la universidad publique algo nuevo.'),
          ),
          const Divider(height: 28),
          Text('Categorías', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: s.avisarImportantes,
            onChanged: s.notificaciones ? ctrl.setAvisarImportantes : null,
            title: const Text('Avisos importantes'),
            secondary: const Icon(Icons.warning_amber_rounded),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: s.avisarRutas,
            onChanged: s.notificaciones ? ctrl.setAvisarRutas : null,
            title: const Text('Cambios de rutas y accesos'),
            secondary: const Icon(Icons.alt_route),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: s.avisarEventos,
            onChanged: s.notificaciones ? ctrl.setAvisarEventos : null,
            title: const Text('Eventos del campus'),
            secondary: const Icon(Icons.event),
          ),
          const SizedBox(height: 20),
          Text(
            'El envío de notificaciones push (a distancia) se conectará más '
            'adelante. Por ahora la app te avisa localmente al abrirla si hay '
            'algo nuevo.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
