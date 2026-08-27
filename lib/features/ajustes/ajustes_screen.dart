import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../design_system/widgets.dart';
import 'settings_controller.dart';

class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const EncabezadoSeccion('Accesibilidad y apariencia'),
          const SizedBox(height: 8),
          Text('Tema', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Sistema'),
                  icon: Icon(Icons.brightness_auto)),
              ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Claro'),
                  icon: Icon(Icons.light_mode)),
              ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Oscuro'),
                  icon: Icon(Icons.dark_mode)),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => ctrl.setThemeMode(v.first),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Tamaño del texto',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text('${(s.textScale * 100).round()}%',
                  style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          Slider(
            value: s.textScale,
            min: 0.85,
            max: 1.5,
            divisions: 13,
            label: '${(s.textScale * 100).round()}%',
            onChanged: (v) => ctrl.setTextScale(v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: s.highContrast,
            onChanged: ctrl.setHighContrast,
            title: const Text('Alto contraste'),
            subtitle: const Text('Aumenta el contraste de bordes y texto.'),
          ),
          const SizedBox(height: 24),
          const EncabezadoSeccion('Cuenta'),
          const SizedBox(height: 8),
          TarjetaUes(
            child: Row(
              children: [
                Icon(Icons.badge_outlined, color: cs.onSurfaceVariant),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConfig.authEnabled
                            ? 'Inicia sesión con tu correo institucional'
                            : 'Inicio de sesión institucional',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppConfig.authEnabled
                            ? 'Guarda favoritos y tu horario.'
                            : 'Pendiente: falta que el área de TI de la UES '
                                'defina la API para validar correo o matrícula. '
                                'Por ahora la app funciona sin cuenta.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                      if (AppConfig.authEnabled) ...[
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () => context.push('/auth'),
                          child: const Text('Continuar'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const EncabezadoSeccion('Acerca de'),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Sistema de diseño UES'),
            subtitle: const Text('Colores, tipografía y componentes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/catalogo'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.dataset_outlined),
            title: Text('Datos de prueba'),
            subtitle: Text(
                'Edificios, aulas y docentes son ejemplos para la demo. Se '
                'reemplazan con el catálogo real y los planos de la UES.'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline),
            title: Text('Versión'),
            subtitle: Text('${AppConfig.nombreApp} 0.1.0 · avance de prácticas'),
          ),
        ],
      ),
    );
  }
}
