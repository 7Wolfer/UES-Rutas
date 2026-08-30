import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../design_system/widgets.dart';
import '../features/atencion/atencion.dart';
import 'brand.dart';
import 'config.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final noLeidos = ref.watch(avisosNoLeidosProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Row(
                children: [
                  SvgPicture.asset('assets/brand/ues_isotipo.svg',
                      height: 34, semanticsLabel: 'Logo UES'),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('UES Rutas',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text('Orientación del campus',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _Item(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notificaciones',
                    trailing: Badge2(noLeidos),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/notificaciones');
                    },
                  ),
                  _Item(
                    icon: Icons.badge_outlined,
                    label: 'Credencialización',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/credencializacion');
                    },
                  ),
                  _Item(
                    icon: Icons.chat_outlined,
                    label: 'Atención por WhatsApp',
                    // El diálogo se muestra sobre el drawer (contexto válido);
                    // el drawer se cierra después.
                    onTap: () => Atencion.whatsApp(context).whenComplete(() {
                      if (context.mounted) Navigator.pop(context);
                    }),
                  ),
                  _Item(
                    icon: Icons.call_outlined,
                    label: 'Llamar a Atención',
                    onTap: () => Atencion.llamar(context).whenComplete(() {
                      if (context.mounted) Navigator.pop(context);
                    }),
                  ),
                  const Divider(height: 16, indent: 20, endIndent: 20),
                  _Item(
                    icon: Icons.tune,
                    label: 'Ajustes',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/ajustes');
                    },
                  ),
                  if (AppConfig.mostrarCatalogoDiseno)
                    _Item(
                      icon: Icons.palette_outlined,
                      label: 'Sistema de diseño',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/catalogo');
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/auth');
                },
                icon: const Icon(Icons.login),
                label: const Text('Iniciar sesión'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: Text('Versión ${AppConfig.version}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: UesBrand.vino),
      title: Text(label, style: Theme.of(context).textTheme.titleSmall),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
