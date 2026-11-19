import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../core/movimiento.dart';

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
    final c = controller;
    Widget campo(bool conTexto) => TextField(
          controller: c,
          autofocus: autofocus,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: AnimatedSwitcher(
              duration: Movimiento.de(context, Movimiento.rapida),
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: conTexto
                  ? IconButton(
                      key: const ValueKey('limpiar'),
                      icon: const Icon(Icons.close),
                      tooltip: 'Limpiar',
                      onPressed: () {
                        c?.clear();
                        onChanged?.call('');
                      },
                    )
                  : const SizedBox.shrink(key: ValueKey('vacio')),
            ),
          ),
        );
    // La "X" escucha al controlador: aparece y desaparece con el texto.
    if (c == null) return campo(false);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: c,
      builder: (context, v, _) => campo(v.text.isNotEmpty),
    );
  }
}

/// Encoge ligeramente a su hijo mientras se presiona (respuesta táctil).
/// No interfiere con el ripple ni con la semántica del hijo.
class Presionable extends StatefulWidget {
  const Presionable({super.key, required this.child, this.escala = 0.96});

  final Widget child;
  final double escala;

  @override
  State<Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<Presionable> {
  bool _abajo = false;

  void _poner(bool v) {
    if (_abajo != v) setState(() => _abajo = v);
  }

  @override
  Widget build(BuildContext context) {
    if (Movimiento.reducido(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _poner(true),
      onPointerUp: (_) => _poner(false),
      onPointerCancel: (_) => _poner(false),
      child: AnimatedScale(
        scale: _abajo ? widget.escala : 1,
        duration: Movimiento.presion,
        curve: Movimiento.estandar,
        child: widget.child,
      ),
    );
  }
}

/// Número que cambia con una transición suave (distancias, minutos).
class NumeroAnimado extends StatelessWidget {
  const NumeroAnimado({
    super.key,
    required this.valor,
    required this.formatear,
    this.estilo,
    this.duracion = Movimiento.lenta,
  });

  final double valor;
  final String Function(double v) formatear;
  final TextStyle? estilo;
  final Duration duracion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: formatear(valor),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: valor),
        duration: Movimiento.de(context, duracion),
        curve: Movimiento.entrada,
        builder: (context, v, _) => Text(formatear(v), style: estilo),
      ),
    );
  }
}

/// Bloque gris con brillo que recorre mientras algo carga. El brillo se
/// detiene solo (y no corre con "reducir movimiento" ni en pruebas).
class EsqueletoCarga extends StatefulWidget {
  const EsqueletoCarga({
    super.key,
    this.ancho = double.infinity,
    this.alto = 14,
    this.radio = 8,
  });

  final double ancho;
  final double alto;
  final double radio;

  @override
  State<EsqueletoCarga> createState() => _EsqueletoCargaState();
}

class _EsqueletoCargaState extends State<EsqueletoCarga>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  int _ciclos = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Movimiento.buclesPermitidos(context) && !_c.isAnimating && _ciclos < 6) {
      _c
        ..addStatusListener(_alTerminar)
        ..forward(from: 0);
    }
  }

  void _alTerminar(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    _ciclos++;
    if (_ciclos < 6 && mounted) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerHighest;
    final brillo = Color.lerp(base, cs.surface, 0.6)!;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final x = -1.5 + 3 * _c.value;
          return Container(
            width: widget.ancho,
            height: widget.alto,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radio),
              gradient: LinearGradient(
                begin: Alignment(x - 0.6, 0),
                end: Alignment(x + 0.6, 0),
                colors: [base, brillo, base],
              ),
            ),
          );
        },
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
          child: AnimatedSwitcher(
            duration: Movimiento.de(context, Movimiento.rapida),
            transitionBuilder: TransicionesUes.fadeThrough,
            child: cargando
                ? const Padding(
                    key: ValueKey('cargando'),
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Icon(icon,
                    key: ValueKey(icon),
                    size: 22,
                    color: activo ? cs.onPrimary : cs.onSurfaceVariant),
          ),
        ),
      ),
    );
    final conPresion = Presionable(child: w);
    return tooltip == null
        ? conPresion
        : Tooltip(message: tooltip!, child: conPresion);
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
    return Presionable(child: _pastilla());
  }

  Widget _pastilla() {
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
