import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/brand.dart';
import 'widgets.dart';

/// Catálogo del sistema de diseño UES. Sirve para revisar rápido el
/// cumplimiento del Manual de Identidad Gráfica y para mostrarlo en la
/// presentación de avance.
class CatalogoScreen extends StatelessWidget {
  const CatalogoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sistema de diseño UES')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const EncabezadoSeccion('Paleta institucional'),
          const SizedBox(height: 8),
          const _Swatch('Naranja · Pantone 1585 C', UesBrand.naranja, '#FF6C0E'),
          const _Swatch('Amarillo · Pantone 137 C', UesBrand.amarillo, '#FFA400'),
          const _Swatch('Vino · Pantone 1955 C', UesBrand.vino, '#8E1537'),
          const SizedBox(height: 8),
          Text(
            'Únicos colores permitidos en comunicación digital. Sin degradados '
            'no oficiales ni sombras sobre el logo.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          const EncabezadoSeccion('Neutros cálidos · extensión digital'),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Mini(UesBrand.neutro0),
              _Mini(UesBrand.neutro50),
              _Mini(UesBrand.neutro100),
              _Mini(UesBrand.neutro200),
              _Mini(UesBrand.neutro300),
              _Mini(UesBrand.neutro500),
              _Mini(UesBrand.neutro700),
              _Mini(UesBrand.neutro900),
            ],
          ),
          const SizedBox(height: 24),
          const EncabezadoSeccion('Categorías de mapa · validar con DDIIUES'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in CategoriaMapa.values)
                ChipCategoria(etiqueta: c.etiqueta, color: c.color, icono: c.icono),
            ],
          ),
          const SizedBox(height: 24),
          const EncabezadoSeccion('Tipografía'),
          const SizedBox(height: 8),
          Text('Montserrat — títulos',
              style: Theme.of(context).textTheme.labelMedium),
          Text('Encabezado de pantalla',
              style: Theme.of(context).textTheme.headlineSmall),
          Text('Título de sección',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text('Source Sans 3 — cuerpo y controles',
              style: Theme.of(context).textTheme.labelMedium),
          Text(
            'El texto de párrafo, listas y botones usa Source Sans 3, que el '
            'manual nombra explícitamente para medios digitales.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          const EncabezadoSeccion('Componentes'),
          const SizedBox(height: 12),
          const CampoBusqueda(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Acción principal')),
              OutlinedButton(onPressed: () {}, child: const Text('Secundaria')),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.directions_walk),
                label: const Text('Cómo llegar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              PastillaAccesible(),
              SizedBox(width: 12),
              AvatarDocente(iniciales: 'LM', radio: 20),
            ],
          ),
          const SizedBox(height: 16),
          TarjetaUes(
            onTap: () {},
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: UesBrand.vino.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text('B',
                      style: TextStyle(
                          color: UesBrand.vino, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EDIFICIO B',
                          style: Theme.of(context).textTheme.labelMedium),
                      Text('Aulas de licenciatura',
                          style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            height: 160,
            child: EstadoVacio(
              icono: Icons.search_off,
              titulo: 'Sin resultados',
              descripcion: 'Ejemplo de estado vacío.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.nombre, this.color, this.hex);
  final String nombre;
  final Color color;
  final String hex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => Clipboard.setData(ClipboardData(text: hex)),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: Theme.of(context).textTheme.titleSmall),
                  Text(hex,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          )),
                ],
              ),
            ),
            const Icon(Icons.copy, size: 16),
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }
}
