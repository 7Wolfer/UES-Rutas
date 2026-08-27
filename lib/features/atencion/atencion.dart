import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';

/// Contacto con el área de Atención. **Número ficticio** por ahora.
// TODO: reemplazar AppConfig.telefonoAtencion por el número real de la UES.
abstract final class Atencion {
  static String get _numero =>
      AppConfig.telefonoAtencion.replaceAll(RegExp(r'[^0-9]'), '');

  static Future<void> whatsApp(BuildContext context) async {
    final ok = await _confirmar(
      context,
      'Abrir WhatsApp',
      'Se abrirá WhatsApp para escribir al área de Atención de la UES.',
    );
    if (!ok) return;
    final uri = Uri.parse(
      'https://wa.me/$_numero?text=${Uri.encodeComponent('Hola, necesito ayuda con la app UES Rutas.')}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> llamar(BuildContext context) async {
    final ok = await _confirmar(
      context,
      'Llamar a Atención',
      'Se abrirá el marcador con el número de Atención de la UES '
          '(${AppConfig.telefonoAtencion}).',
    );
    if (!ok) return;
    await launchUrl(Uri(scheme: 'tel', path: AppConfig.telefonoAtencion));
  }

  static Future<bool> _confirmar(
      BuildContext context, String titulo, String cuerpo) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text('$cuerpo\n\nVas a salir de UES Rutas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return r ?? false;
  }
}
