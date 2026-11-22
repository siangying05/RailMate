import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static const String channelId = 'railmate_arrival';
  static const String channelName = 'Arrival alerts';
  static const String channelDescription =
      'Reminds you when your stop or interchange is coming up.';

  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _permitted = false;

  bool get isReady => _ready;
  bool get isPermitted => _permitted;

  Future<void> initialise() async {
    if (_ready) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    try {
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: darwin),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<bool> requestPermission() async {
    await initialise();
    if (!_ready) return false;

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        _permitted = await android.requestNotificationsPermission() ?? false;
        return _permitted;
      }

      final darwin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (darwin != null) {
        _permitted = await darwin.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
        return _permitted;
      }
    } catch (_) {
      _permitted = false;
    }

    return _permitted;
  }

  Future<void> showArrivalAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialise();
    if (!_ready) return;

    const android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.navigation,
    );
    const darwin = DarwinNotificationDetails();

    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(android: android, iOS: darwin),
      );
    } catch (_) {
      return;
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {
      return;
    }
  }
}
