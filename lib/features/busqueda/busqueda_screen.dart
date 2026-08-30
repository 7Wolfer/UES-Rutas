import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/busqueda.dart';
import '../../data/providers.dart';
import '../../design_system/widgets.dart';

class BusquedaScreen extends ConsumerStatefulWidget {
  const BusquedaScreen({super.key, this.consultaInicial});

  final String? consultaInicial;

  @override
  ConsumerState<BusquedaScreen> createState() => _BusquedaScreenState();
}

class _BusquedaScreenState extends ConsumerState<BusquedaScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.consultaInicial ?? '');
  // Estado local, desacoplado de la hoja de inicio.
  late String _consulta = _controller.text;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _consulta = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(campusDataProvider).valueOrNull;
    final consulta = _consulta.trim();
    final resultados = (data == null || consulta.isEmpty)
        ? const <ResultadoBusqueda>[]
        : buscar(data, consulta);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: CampoBusqueda(
              controller: _controller,
              autofocus: widget.consultaInicial == null,
              onChanged: _onChanged,
            ),
          ),
        ),
      ),
      body: consulta.isEmpty
          ? const EstadoVacio(
              icono: Icons.search,
              titulo: 'Escribe para buscar',
              descripcion:
                  'Aulas (AULA B-101), edificios (EDIFICIO E), servicios o el '
                  'nombre de un docente.',
            )
          : resultados.isEmpty
              ? const EstadoVacio(
                  icono: Icons.search_off,
                  titulo: 'Sin resultados',
                  descripcion: 'Prueba con otro término.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: resultados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _FilaResultado(resultado: resultados[i]),
                ),
    );
  }
}

class _FilaResultado extends StatelessWidget {
  const _FilaResultado({required this.resultado});

  final ResultadoBusqueda resultado;

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    return TarjetaUes(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () {
        switch (r.tipo) {
          case TipoResultado.docente:
            context.push('/docente/${r.id}');
          case TipoResultado.lugar:
            context.push('/espacio/${r.id}');
        }
      },
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: r.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(r.icono, color: r.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.titulo,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  r.subtitulo,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
