import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'config.dart';

/// Construye la URL absoluta de una ruta interna de la app.
///
/// `construirUrlCompartible(base: 'https://ues-rutas.app', ruta: '/espacio/x')`
/// → `'https://ues-rutas.app/#/espacio/x'`
String construirUrlCompartible({required String base, required String ruta}) {
  final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return '$b/#$ruta';
}

String _baseActual() {
  if (kIsWeb) {
    final u = Uri.base;
    return '${u.origin}${u.path}';
  }
  return AppConfig.urlPublica;
}

/// Comparte un enlace a una pantalla de la app.
///
/// - Móvil: abre la hoja de compartir del sistema (WhatsApp, etc.).
/// - Web: copia el enlace al portapapeles y muestra un aviso.
Future<void> compartir(
  BuildContext context, {
  required String titulo,
  required String ruta,
}) async {
  final url = construirUrlCompartible(base: _baseActual(), ruta: ruta);

  if (kIsWeb) {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace copiado')),
      );
    }
    return;
  }

  final caja = context.findRenderObject() as RenderBox?;
  final origen = caja != null && caja.hasSize
      ? caja.localToGlobal(Offset.zero) & caja.size
      : null;

  await SharePlus.instance.share(
    ShareParams(
      text: '$titulo\n$url',
      subject: titulo,
      sharePositionOrigin: origen,
    ),
  );
}
