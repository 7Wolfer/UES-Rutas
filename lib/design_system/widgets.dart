import 'package:flutter/material.dart';

import '../core/brand.dart';

/// Campo de búsqueda universal (aula, edificio, servicio, docente).
class CampoBusqueda extends StatelessWidget {
  const CampoBusqueda({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.hintText = 'Buscar edificio, servicio o docente',
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: (controller?.text.isNotEmpty ?? false)
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Limpiar',
                onPressed: () {
                  controller?.clear();
                  onChanged?.call('');
                },
              )
            : null,
      ),
    );
  }
}

/// Insignia "Accesible" para espacios sin barreras.
class PastillaAccesible extends StatelessWidget {
  const PastillaAccesible({super.key, this.compacta = false});

  final bool compacta;

  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF2457A6);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacta ? 6 : 10,
        vertical: compacta ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: azul.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.accessible, size: 15, color: azul),
          if (!compacta) ...[
            const SizedBox(width: 4),
            Text(
              'Accesible',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: azul, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

/// Avatar circular con iniciales para docentes (mientras no hay foto).
class AvatarDocente extends StatelessWidget {
  const AvatarDocente({super.key, required this.iniciales, this.radio = 24});

  final String iniciales;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radio,
      backgroundColor: UesBrand.vino.withValues(alpha: 0.12),
      child: Text(
        iniciales,
        style: TextStyle(
          color: UesBrand.vino,
          fontWeight: FontWeight.w700,
          fontSize: radio * 0.7,
        ),
      ),
    );
  }
}

/// Chip de categoría con punto de color.
class ChipCategoria extends StatelessWidget {
  const ChipCategoria({
    super.key,
    required this.etiqueta,
    required this.color,
    this.icono,
    this.seleccionado = false,
    this.onTap,
  });

  final String etiqueta;
  final Color color;
  final IconData? icono;
  final bool seleccionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: seleccionado
          ? color.withValues(alpha: 0.16)
          : Theme.of(context).chipTheme.backgroundColor,
      shape: StadiumBorder(
        side: BorderSide(
          color: seleccionado ? color : cs.outlineVariant,
          width: seleccionado ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null)
                Icon(icono, size: 16, color: color)
              else
                Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              const SizedBox(width: 6),
              Text(
                etiqueta,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Encabezado de sección con estilo Montserrat.
class EncabezadoSeccion extends StatelessWidget {
  const EncabezadoSeccion(this.texto, {super.key, this.accion});

  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          if (accion != null) accion!,
        ],
      ),
    );
  }
}

/// Tarjeta táctil genérica (borde, radio 16, sin sombra).
class TarjetaUes extends StatelessWidget {
  const TarjetaUes({super.key, required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).cardTheme.color ?? cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Estado vacío / sin resultados / error.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.descripcion,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? descripcion;

  /// Botón opcional (p. ej. "Reintentar" / "Ir al inicio").
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (descripcion != null) ...[
              const SizedBox(height: 4),
              Text(
                descripcion!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            if (accion != null) ...[
              const SizedBox(height: 20),
              accion!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Botón circular elevado para controles flotantes sobre el mapa.
class BotonCircularMapa extends StatelessWidget {
  const BotonCircularMapa({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.activo = false,
    this.cargando = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool activo;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = Material(
      color: activo ? cs.primary : cs.surface,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: cargando ? null : onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: cargando
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : Icon(icon,
                  size: 22, color: activo ? cs.onPrimary : cs.onSurfaceVariant),
        ),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip!, child: w);
  }
}

/// Pastilla de acción principal (barra superior del mapa).
class PastillaAccion extends StatelessWidget {
  const PastillaAccion({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: UesBrand.naranja,
      borderRadius: BorderRadius.circular(999),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: const Color(0xFF2A1200)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF2A1200),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Handle de arrastre para hojas inferiores.
class HandleHoja extends StatelessWidget {
  const HandleHoja({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

/// Insignia numérica (badge) para el drawer.
class Badge2 extends StatelessWidget {
  const Badge2(this.count, {super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: UesBrand.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
