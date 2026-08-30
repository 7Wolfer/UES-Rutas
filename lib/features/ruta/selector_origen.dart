import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/busqueda.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../design_system/widgets.dart';
import '../../services/ubicacion_service.dart';

/// Abre una hoja para elegir el punto de partida de una ruta. Devuelve el id del
/// lugar elegido, [Lugar.idMiUbicacion], o `null` si se cerró sin elegir.
Future<String?> mostrarSelectorOrigen(
  BuildContext context, {
  required CampusData campus,
  required String destinoId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SelectorOrigen(campus: campus, destinoId: destinoId),
  );
}

class _SelectorOrigen extends ConsumerStatefulWidget {
  const _SelectorOrigen({required this.campus, required this.destinoId});

  final CampusData campus;
  final String destinoId;

  @override
  ConsumerState<_SelectorOrigen> createState() => _SelectorOrigenState();
}

class _SelectorOrigenState extends ConsumerState<_SelectorOrigen> {
  final _busqueda = TextEditingController();
  bool _localizando = false;
  EstadoUbicacion? _errorUbicacion;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _usarMiUbicacion() async {
    setState(() {
      _localizando = true;
      _errorUbicacion = null;
    });
    final r = await ref.read(posicionUsuarioProvider.notifier).localizar();
    if (!mounted) return;
    if (r.exito) {
      Navigator.pop(context, Lugar.idMiUbicacion);
      return;
    }
    setState(() {
      _localizando = false;
      _errorUbicacion = r.estado;
    });
  }

  List<Lugar> _lugaresFiltrados() {
    final q = _busqueda.text.trim();
    if (q.isNotEmpty) {
      return buscar(widget.campus, q)
          .where((r) =>
              r.tipo == TipoResultado.lugar && r.id != widget.destinoId)
          .map((r) => widget.campus.lugar(r.id))
          .whereType<Lugar>()
          .toList();
    }
    return widget.campus.lugares
        .where((l) => l.id != widget.destinoId)
        .toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lugares = _lugaresFiltrados();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            const HandleHoja(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Punto de partida',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('Desde mi ubicación'),
              trailing: _localizando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _localizando ? null : _usarMiUbicacion,
            ),
            if (_errorUbicacion != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _AvisoUbicacion(
                  estado: _errorUbicacion!,
                  onReintentar: _usarMiUbicacion,
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: CampoBusqueda(
                controller: _busqueda,
                hintText: 'Buscar lugar del campus',
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: lugares.isEmpty
                  ? const EstadoVacio(
                      icono: Icons.search_off,
                      titulo: 'Sin resultados',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: lugares.length,
                      itemBuilder: (context, i) {
                        final l = lugares[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                l.categoria.color.withValues(alpha: 0.15),
                            child: Icon(l.categoria.icono,
                                size: 16, color: l.categoria.color),
                          ),
                          title: Text(l.nombre),
                          subtitle: Text(l.categoria.etiqueta),
                          trailing: l.accesible
                              ? Icon(Icons.accessible,
                                  size: 18, color: cs.onSurfaceVariant)
                              : null,
                          onTap: () => Navigator.pop(context, l.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvisoUbicacion extends StatelessWidget {
  const _AvisoUbicacion({required this.estado, required this.onReintentar});

  final EstadoUbicacion estado;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (String texto, String? accion, Future<bool> Function()? alTocar) =
        switch (estado) {
      EstadoUbicacion.servicioApagado => (
          'La ubicación del dispositivo está apagada.',
          'Abrir ajustes',
          UbicacionService.instance.abrirAjustesUbicacion,
        ),
      EstadoUbicacion.permisoBloqueado => (
          'El permiso de ubicación está bloqueado. Actívalo en los ajustes de '
              'la app.',
          'Abrir ajustes',
          UbicacionService.instance.abrirAjustesApp,
        ),
      EstadoUbicacion.permisoDenegado => (
          'Necesitas permitir el acceso a tu ubicación para usar esta opción.',
          null,
          null,
        ),
      _ => (
          'No se pudo obtener tu ubicación. Intenta de nuevo.',
          null,
          null,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 18, color: cs.onSecondaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(texto,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSecondaryContainer,
                        )),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onReintentar,
                child: const Text('Reintentar'),
              ),
              if (accion != null) ...[
                const SizedBox(width: 4),
                FilledButton.tonal(
                  onPressed: () {
                    alTocar?.call();
                  },
                  child: Text(accion),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
