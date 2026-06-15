import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/alert.dart';
import 'settings_service.dart';

/// In-memory alert log (max 50, like the web app) with persistence of the last
/// 20 entries, plus local SOS notifications.
class AlertService {
  static const int _maxAlerts = 50;
  static const int _persistCount = 20;
  static const String _storeKey = 'sina_alert_log';

  final List<SinaAlert> alerts = [];
  int _nextId = 1;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _notifInit = false;

  Future<void> init() async {
    _load();
    await _initNotifications();
  }

  Future<void> _initNotifications() async {
    if (_notifInit) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _notifications.initialize(settings);
      _notifInit = true;
    } catch (_) {
      _notifInit = false;
    }
  }

  void _load() {
    final raw = SettingsService.instance.getRaw(_storeKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => SinaAlert.fromJson(e as Map<String, dynamic>))
          .toList();
      alerts
        ..clear()
        ..addAll(list);
      if (alerts.isNotEmpty) {
        _nextId = alerts.map((a) => a.id).reduce((a, b) => a > b ? a : b) + 1;
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    final slice = alerts.take(_persistCount).map((a) => a.toJson()).toList();
    await SettingsService.instance.setRaw(_storeKey, jsonEncode(slice));
  }

  /// Add an alert at the front of the log. Returns the created alert.
  Future<SinaAlert> addAlert(String message, double? lat, double? lng) async {
    final alert = SinaAlert(
      id: _nextId++,
      message: message,
      lat: lat,
      lng: lng,
      timestamp: DateTime.now(),
    );
    alerts.insert(0, alert);
    while (alerts.length > _maxAlerts) {
      alerts.removeLast();
    }
    await _persist();
    return alert;
  }

  Future<void> showSosNotification(String body) async {
    await _initNotifications();
    if (!_notifInit) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'sina_sos',
          'SINA SOS Alerts',
          channelDescription: 'Emergency alerts triggered by SINA',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          category: AndroidNotificationCategory.alarm,
        ),
      );
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'SINA SOS',
        body,
        details,
      );
    } catch (_) {}
  }

  Future<bool> requestNotificationPermission() async {
    try {
      final android =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }
}
