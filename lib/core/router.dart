import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design_system/catalogo_screen.dart';
import '../design_system/widgets.dart';
import '../features/ajustes/ajustes_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/busqueda/busqueda_screen.dart';
import '../features/credencializacion/credencializacion_screen.dart';
import '../features/docente/docente_screen.dart';
import '../features/espacio/espacio_screen.dart';
import '../features/home/mapa_home_screen.dart';
import '../features/notificaciones/notificaciones_ajustes_screen.dart';
import '../features/notificaciones/notificaciones_screen.dart';
import '../features/ruta/ruta_screen.dart';

CustomTransitionPage<void> _fade(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, _, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('UES Rutas')),
      body: EstadoVacio(
        icono: Icons.explore_off_outlined,
        titulo: 'No encontramos esa página',
        descripcion: 'El enlace puede estar mal escrito o ya no existe.',
        accion: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Ir al inicio'),
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (c, s) => _fade(const MapaHomeScreen(), s),
      ),
      GoRoute(
        path: '/notificaciones',
        pageBuilder: (c, s) => _fade(const NotificacionesScreen(), s),
        routes: [
          GoRoute(
            path: 'ajustes',
            pageBuilder: (c, s) =>
                _fade(const NotificacionesAjustesScreen(), s),
          ),
        ],
      ),
      GoRoute(
        path: '/credencializacion',
        pageBuilder: (c, s) => _fade(const CredencializacionScreen(), s),
      ),
      GoRoute(
        path: '/ajustes',
        pageBuilder: (c, s) => _fade(const AjustesScreen(), s),
      ),
      GoRoute(
        path: '/auth',
        pageBuilder: (c, s) => _fade(const AuthScreen(), s),
      ),
      GoRoute(
        path: '/buscar',
        pageBuilder: (c, s) => _fade(
          BusquedaScreen(consultaInicial: s.uri.queryParameters['q']),
          s,
        ),
      ),
      GoRoute(
        path: '/espacio/:id',
        pageBuilder: (c, s) =>
            _fade(EspacioScreen(id: s.pathParameters['id']!), s),
      ),
      GoRoute(
        path: '/docente/:id',
        pageBuilder: (c, s) =>
            _fade(DocenteScreen(id: s.pathParameters['id']!), s),
      ),
      GoRoute(
        path: '/ruta',
        pageBuilder: (c, s) {
          final q = s.uri.queryParameters;
          return _fade(
            RutaScreen(
              destinoId: q['destino'] ?? 'lug_acceso_principal',
              origenId: q['origen'] ?? 'lug_acceso_principal',
              accesibleInicial: q['accesible'] == '1',
            ),
            s,
          );
        },
      ),
      GoRoute(
        path: '/catalogo',
        pageBuilder: (c, s) => _fade(const CatalogoScreen(), s),
      ),
    ],
  );
});
