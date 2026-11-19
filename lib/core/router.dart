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
        builder: (c, s) => const MapaHomeScreen(),
      ),
      GoRoute(
        path: '/notificaciones',
        builder: (c, s) => const NotificacionesScreen(),
        routes: [
          GoRoute(
            path: 'ajustes',
            builder: (c, s) => const NotificacionesAjustesScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/credencializacion',
        builder: (c, s) => const CredencializacionScreen(),
      ),
      GoRoute(
        path: '/ajustes',
        builder: (c, s) => const AjustesScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (c, s) => const AuthScreen(),
      ),
      GoRoute(
        path: '/buscar',
        builder: (c, s) =>
            BusquedaScreen(consultaInicial: s.uri.queryParameters['q']),
      ),
      GoRoute(
        path: '/espacio/:id',
        builder: (c, s) => EspacioScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/docente/:id',
        builder: (c, s) => DocenteScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/ruta',
        builder: (c, s) {
          final q = s.uri.queryParameters;
          return RutaScreen(
            destinoId: q['destino'] ?? 'lug_acceso_principal',
            origenId: q['origen'] ?? 'lug_acceso_principal',
            accesibleInicial: q['accesible'] == '1',
          );
        },
      ),
      GoRoute(
        path: '/catalogo',
        builder: (c, s) => const CatalogoScreen(),
      ),
    ],
  );
});
