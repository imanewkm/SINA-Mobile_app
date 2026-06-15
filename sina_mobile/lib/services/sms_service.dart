import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Sends an SOS text message directly via the native Android SmsManager.
///
/// Unlike a `sms:` deep link, this delivers without any taps and without
/// internet (cellular only) — essential for a blind user in an emergency.
/// Mirrors the "com.sina.mobility/sms" MethodChannel in MainActivity.kt.
class SmsService {
  static const MethodChannel _ch = MethodChannel('com.sina.mobility/sms');

  Future<bool> hasPermission() => Permission.sms.isGranted;

  /// Request SEND_SMS up front (e.g. on activation) so the emergency path is
  /// never blocked by a permission prompt during a panic.
  Future<bool> requestPermission() async =>
      (await Permission.sms.request()).isGranted;

  /// Send [message] to [phone]. Returns true only if the SMS was handed to the
  /// radio successfully. Never throws.
  Future<bool> send(String phone, String message) async {
    if (phone.trim().isEmpty || message.trim().isEmpty) return false;
    try {
      if (!await Permission.sms.request().isGranted) return false;
      final ok = await _ch.invokeMethod<bool>('send', {
        'phone': phone.trim(),
        'message': message,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
