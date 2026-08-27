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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(consultaBusquedaProvider.notifier).state = _controller.text;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() {});
    ref.read(consultaBusquedaProvider.notifier).state = v;
  }

  @override
  Widget build(BuildContext context) {
    final resultados = ref.watch(resultadosBusquedaProvider);
    final consulta = ref.watch(consultaBusquedaProvider);

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
      body: consulta.trim().isEmpty
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
          case TipoResultado.espacio:
          case TipoResultado.edificio:
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
