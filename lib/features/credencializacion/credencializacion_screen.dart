import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/brand.dart';
import '../../data/calendario.dart';
import '../../data/providers.dart';
import '../../design_system/widgets.dart';

class CredencializacionScreen extends ConsumerWidget {
  const CredencializacionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Credencialización'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Credencial'),
              Tab(text: 'Calendario'),
              Tab(text: 'Requisitos'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TabCredencial(),
            _TabCalendario(),
            _TabRequisitos(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Credencial digital (mock)
// ---------------------------------------------------------------------------

class _TabCredencial extends StatelessWidget {
  const _TabCredencial();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // La credencial es un artefacto de tamaño fijo (como un pase de
        // Wallet): su texto no escala para no deformar la tarjeta.
        MediaQuery(
          data:
              MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: Semantics(
            label: 'Credencial digital de ejemplo. Los datos se llenan al '
                'iniciar sesión.',
            excludeSemantics: true,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: AspectRatio(
                  aspectRatio: 1.6,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [UesBrand.vino, UesBrand.vinoOscuro],
                          ),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black26,
                                blurRadius: 16,
                                offset: Offset(0, 6)),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SvgPicture.asset(
                                  'assets/brand/ues_isotipo.svg',
                                  height: 26,
                                  colorFilter: const ColorFilter.mode(
                                      Colors.white, BlendMode.srcIn),
                                ),
                                const SizedBox(width: 8),
                                const Text('UES',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20,
                                        letterSpacing: 1)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Universidad Estatal de Sonora',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.85),
                                          fontSize: 10)),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('ESTUDIANTE',
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.7),
                                              fontSize: 9,
                                              letterSpacing: 1.5)),
                                      const Text('Nombre Apellido Apellido',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16)),
                                      const SizedBox(height: 6),
                                      Text('Matrícula 00000000',
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.9),
                                              fontSize: 12)),
                                      Text('Ing. de Software · 6.º semestre',
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.9),
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: QrImageView(
                                    data: 'UESRUTAS-DEMO-00000000',
                                    size: 62,
                                    padding: EdgeInsets.zero,
                                    semanticsLabel:
                                        'Código QR de la credencial (demo)',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 14,
                        right: -30,
                        child: Transform.rotate(
                          angle: 0.785,
                          child: Container(
                            color: UesBrand.amarillo,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 34, vertical: 3),
                            child: const Text('PROTOTIPO',
                                style: TextStyle(
                                    color: Color(0xFF3E2E00),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    letterSpacing: 1)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Vista previa de la credencial digital. Los datos son de ejemplo; se '
          'llenarán con tu información al iniciar sesión con el correo '
          'institucional.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Calendario académico
// ---------------------------------------------------------------------------

class _TabCalendario extends ConsumerStatefulWidget {
  const _TabCalendario();

  @override
  ConsumerState<_TabCalendario> createState() => _TabCalendarioState();
}

class _TabCalendarioState extends ConsumerState<_TabCalendario> {
  DateTime _focused = DateTime(2026, 8, 26);
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final calAsync = ref.watch(calendarioProvider);
    final cs = Theme.of(context).colorScheme;

    return calAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EstadoVacio(
          icono: Icons.error_outline, titulo: 'Error', descripcion: '$e'),
      data: (cal) {
        final sel = _selected;
        final eventosSel =
            sel == null ? const <EventoCalendario>[] : cal.eventosDe(sel);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            TarjetaUes(
              child: Row(
                children: [
                  const Icon(Icons.school_outlined, color: UesBrand.vino),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Semestre en curso',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                        Text(cal.semestreActual.nombre,
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(
                          'Inicio ${DateFormat("d MMM", "es").format(cal.semestreActual.inicio)}'
                          ' · Fin de clases ${DateFormat("d MMM", "es").format(cal.semestreActual.fin)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: TableCalendar<EventoCalendario>(
                  locale: 'es',
                  firstDay: DateTime(2026, 1, 1),
                  lastDay: DateTime(2027, 2, 28),
                  focusedDay: _focused,
                  currentDay: DateTime.now(),
                  availableGestures: AvailableGestures.horizontalSwipe,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    todayDecoration: BoxDecoration(
                      color: UesBrand.naranja.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(color: cs.onSurface),
                    selectedDecoration: const BoxDecoration(
                      color: UesBrand.vino,
                      shape: BoxShape.circle,
                    ),
                  ),
                  selectedDayPredicate: (d) => isSameDay(_selected, d),
                  eventLoader: cal.eventosDe,
                  onDaySelected: (selected, focused) => setState(() {
                    _selected = selected;
                    _focused = focused;
                  }),
                  onPageChanged: (f) => _focused = f,
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return null;
                      return Positioned(
                        bottom: 2,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final e in events.take(3))
                              Container(
                                width: 6,
                                height: 6,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 0.5),
                                decoration: BoxDecoration(
                                  color: e.tipo.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (sel != null)
              _PanelDia(fecha: sel, eventos: eventosSel)
            else
              Text(
                'Toca un día para ver qué se celebra o suspende.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            const SizedBox(height: 20),
            const EncabezadoSeccion('Simbología'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final t in TipoEventoCal.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: t.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(t.etiqueta,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => Dialog(
                  child: InteractiveViewer(
                    child: Image.asset(
                      'assets/docs/calendario-ues-2026-2027.png',
                      semanticLabel: 'Calendario escolar UES 2026-2027',
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Ver calendario oficial'),
            ),
            const SizedBox(height: 12),
            Text(
              '${cal.nota}\n${cal.firmantes.join(' · ')}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}

class _PanelDia extends StatelessWidget {
  const _PanelDia({required this.fecha, required this.eventos});
  final DateTime fecha;
  final List<EventoCalendario> eventos;

  @override
  Widget build(BuildContext context) {
    final f = DateFormat("EEEE d 'de' MMMM", 'es').format(fecha);
    return TarjetaUes(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f[0].toUpperCase() + f.substring(1),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (eventos.isEmpty)
            Text('Día hábil normal.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ))
          else
            ...eventos.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: e.tipo.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(e.titulo,
                              style: Theme.of(context).textTheme.bodyMedium)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Requisitos
// ---------------------------------------------------------------------------

class _TabRequisitos extends StatelessWidget {
  const _TabRequisitos();

  static const _pasos = [
    ('Comprobante de inscripción vigente', Icons.assignment_turned_in_outlined),
    ('Identificación oficial (INE o pasaporte)', Icons.badge_outlined),
    ('CURP impresa', Icons.description_outlined),
    (
      'Una fotografía tamaño infantil, fondo blanco',
      Icons.photo_camera_outlined
    ),
    ('Comprobante de pago de credencial', Icons.receipt_long_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text('Para tramitar tu credencial en Control Escolar UES:',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        ..._pasos.map((p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(p.$2, color: UesBrand.vino),
              title: Text(p.$1),
            )),
        const SizedBox(height: 16),
        Text(
          'Contenido de ejemplo para el prototipo. Los requisitos oficiales los '
          'define Servicios Escolares de la UES.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
