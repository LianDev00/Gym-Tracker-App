import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Wrapper alrededor de `flutter_local_notifications` para el timer de descanso.
///
/// - Una sola notificación tipo "alarm" programada con `zonedSchedule` para
///   que dispare en el segundo exacto incluso con la pantalla apagada o la
///   app cerrada.
/// - Sonido y vibración por defecto del sistema (canal con `Importance.high`).
/// - Tap en la notificación abre la app (intent default).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'rest_timer';
  static const _channelName = 'Temporizador de descanso';
  static const _channelDesc =
      'Avisa cuando termina el tiempo de descanso entre series.';
  static const _restTimerNotifId = 1001;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // Detectar la zona horaria local del dispositivo.
    try {
      tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
    } catch (_) {
      // Fallback: usa UTC si el nombre del timezone no resuelve.
      // El cálculo de offset igual se hace en local mediante `DateTime.now()`.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Canal Android — alta prioridad para que suene/vibre aunque la pantalla
    // esté apagada. Usa el sonido por defecto del sistema.
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Pide permisos de notificación al usuario (Android 13+ e iOS). Idempotente.
  Future<bool> requestPermissionIfNeeded() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    bool granted = true;
    final androidResult = await android?.requestNotificationsPermission();
    if (androidResult != null) granted = granted && androidResult;
    final iosResult = await ios?.requestPermissions(alert: true, sound: true);
    if (iosResult != null) granted = granted && iosResult;
    return granted;
  }

  /// Programa la notificación de "descanso terminado" para dentro de [in_].
  /// Si ya había una pendiente, la sobreescribe (mismo id).
  Future<void> scheduleRestTimerEnd(Duration in_) async {
    await init();
    final fireAt = tz.TZDateTime.now(tz.local).add(in_);
    try {
      await _plugin.zonedSchedule(
        _restTimerNotifId,
        '¡Descanso terminado!',
        'Toca para volver a la sesión.',
        fireAt,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      debugPrint('No se pudo programar la notificación: $e\n$st');
    }
  }

  /// Cancela la notificación pendiente (si la hay).
  Future<void> cancelRestTimerEnd() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_restTimerNotifId);
    } catch (_) {/* no-op */}
  }
}
