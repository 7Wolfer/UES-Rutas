import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../data/models.dart';
import '../../data/routing.dart';
import 'campus_map_painter.dart';

/// Mapa ilustrativo del campus, reutilizable: pestaña Mapa y pantalla de Ruta.
class MapaCampus extends StatefulWidget {
  const MapaCampus({
    super.key,
    required this.data,
    this.ruta,
    this.destacarEspacioId,
    this.onTapEspacio,
    this.nivelInicial = 0,
    this.mostrarSelectorNivel = true,
  });

  final CampusData data;
  final RutaCalculada? ruta;
  final String? destacarEspacioId;
  final ValueChanged<Espacio>? onTapEspacio;
  final int nivelInicial;
  final bool mostrarSelectorNivel;

  @override
  State<MapaCampus> createState() => _MapaCampusState();
}

class _MapaCampusState extends State<MapaCampus> {
  late int _nivel = widget.nivelInicial;
  final _tc = TransformationController();

  List<int> get _niveles {
    final set = <int>{0};
    for (final e in widget.data.edificios) {
      set.addAll(e.niveles);
    }
    final l = set.toList()..sort();
    return l;
  }

  @override
  void didUpdateWidget(covariant MapaCampus old) {
    super.didUpdateWidget(old);
    if (old.nivelInicial != widget.nivelInicial) _nivel = widget.nivelInicial;
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _tap(Offset local, double s) {
    if (widget.onTapEspacio == null) return;
    final canvas = local / s;
    Espacio? mejor;
    var mejorD = 26.0;
    for (final e in widget.data.espacios) {
      if (e.tipo == TipoEspacio.edificio) continue;
      final visible = e.edificioId == null || e.nivel == _nivel;
      if (!visible) continue;
      final d = (Offset(e.punto.x, e.punto.y) - canvas).distance;
      if (d < mejorD) {
        mejorD = d;
        mejor = e;
      }
    }
    if (mejor != null) widget.onTapEspacio!(mejor);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, c) {
              // Ajusta el lienzo del campus para que quepa completo (contain).
              final aspect = kCampusLienzo.width / kCampusLienzo.height;
              var w = c.maxWidth;
              var h = w / aspect;
              if (h > c.maxHeight) {
                h = c.maxHeight;
                w = h * aspect;
              }
              final s = w / kCampusLienzo.width;
              return Center(
                child: SizedBox(
                  width: w,
                  height: h,
                  child: InteractiveViewer(
                    transformationController: _tc,
                    minScale: 1,
                    maxScale: 5,
                    child: GestureDetector(
                      onTapUp: (d) => _tap(d.localPosition, s),
                      child: CustomPaint(
                        size: Size(w, h),
                        painter: CampusMapPainter(
                          data: widget.data,
                          nivel: _nivel,
                          brightness: brightness,
                          ruta: widget.ruta,
                          destacarEspacioId: widget.destacarEspacioId,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.mostrarSelectorNivel && _niveles.length > 1)
          Positioned(
            top: 12,
            right: 12,
            child: _SelectorNivel(
              niveles: _niveles,
              actual: _nivel,
              onCambio: (n) => setState(() => _nivel = n),
            ),
          ),
        Positioned(
          left: 12,
          bottom: 12,
          child: _BotonReset(onTap: () => _tc.value = Matrix4.identity()),
        ),
      ],
    );
  }
}

class _SelectorNivel extends StatelessWidget {
  const _SelectorNivel({
    required this.niveles,
    required this.actual,
    required this.onCambio,
  });

  final List<int> niveles;
  final int actual;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            for (final n in niveles.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: SizedBox(
                  width: 48,
                  height: 40,
                  child: FilledButton(
                    onPressed: () => onCambio(n),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: n == actual
                          ? cs.primary
                          : cs.surfaceContainerHighest,
                      foregroundColor:
                          n == actual ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                    child: Text(
                      etiquetaNivelCorta(n),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BotonReset extends StatelessWidget {
  const _BotonReset({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      shape: const CircleBorder(),
      color: Theme.of(context).colorScheme.surface,
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.center_focus_strong_outlined),
        tooltip: 'Centrar mapa',
      ),
    );
  }
}
