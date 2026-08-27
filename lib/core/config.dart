/// Configuración de compilación y feature flags.
///
/// Los valores se pueden sobreescribir en tiempo de compilación con
/// `--dart-define`, por ejemplo:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJh...
///   --dart-define=AUTH_ENABLED=true
/// ```
abstract final class AppConfig {
  /// Nombre visible de la app.
  static const String nombreApp = 'UES Rutas';

  /// Versión visible (coincide con `pubspec.yaml`).
  static const String version = '0.2.0';

  /// Número de Atención (WhatsApp / llamada). **Ficticio** hasta tener el real.
  static const String telefonoAtencion = '+526620000000';

  /// URL del proyecto Supabase. Vacío = backend deshabilitado (modo seed local).
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  /// Clave pública (anon) de Supabase.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// ¿Está configurado Supabase?
  static bool get supabaseConfigurado =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Feature flag: pantalla de inicio de sesión.
  ///
  /// `false` por defecto → la app se usa **sin cuenta** (modo visitante).
  /// La restricción por correo institucional / matrícula todavía NO está
  /// implementada: depende de lo que confirme el área de TI de la UES.
  static const bool authEnabled =
      bool.fromEnvironment('AUTH_ENABLED', defaultValue: false);

  /// Dominio del correo institucional (para cuando se active la validación).
  static const String dominioInstitucional = 'ues.mx';

  /// Muestra el acceso al catálogo de componentes (design system) en Ajustes.
  static const bool mostrarCatalogoDiseno = true;
}
