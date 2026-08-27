import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design_system/catalogo_screen.dart';
import '../features/ajustes/ajustes_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/busqueda/busqueda_screen.dart';
import '../features/docente/docente_screen.dart';
import '../features/espacio/espacio_screen.dart';
import '../features/inicio/inicio_screen.dart';
import '../features/mapa/mapa_screen.dart';
import '../features/ruta/ruta_screen.dart';
import '../features/shell/scaffold_con_nav.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/inicio',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldConNav(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inicio',
                builder: (context, state) => const InicioScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mapa',
                builder: (context, state) => const MapaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ajustes',
                builder: (context, state) => const AjustesScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/buscar',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => BusquedaScreen(
          consultaInicial: state.uri.queryParameters['q'],
        ),
      ),
      GoRoute(
        path: '/espacio/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            EspacioScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/docente/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            DocenteScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/ruta',
        parentNavigatorKey: _rootKey,
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return RutaScreen(
            destinoId: q['destino'] ?? 'esp_edif_a',
            origenId: q['origen'] ?? 'esp_acceso',
            accesibleInicial: q['accesible'] == '1',
          );
        },
      ),
      GoRoute(
        path: '/catalogo',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const CatalogoScreen(),
      ),
      GoRoute(
        path: '/auth',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const AuthScreen(),
      ),
    ],
  );
});
