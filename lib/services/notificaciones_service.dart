import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Envoltura sobre `flutter_local_notifications`. Solo notificaciones **locales**
/// del dispositivo; el envío push remoto (FCM) es una fase posterior.
class NotificacionesService {
  NotificacionesService._();
  static final NotificacionesService instance = NotificacionesService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _listo = false;

  static const _canal = AndroidNotificationChannel(
    'avisos_ues',
    'Avisos UES',
    description: 'Avisos importantes, eventos y cambios de accesos del campus.',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_listo || kIsWeb) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_canal);
    _listo = true;
  }

  /// Pide permiso de notificaciones (iOS y Android 13+).
  Future<bool> pedirPermiso() async {
    if (kIsWeb) return false;
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return ios ?? android ?? false;
  }

  Future<void> mostrar({
    required int id,
    required String titulo,
    required String cuerpo,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await init();
    await _plugin.show(
      id,
      titulo,
      cuerpo,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _canal.id,
          _canal.name,
          channelDescription: _canal.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }
}
