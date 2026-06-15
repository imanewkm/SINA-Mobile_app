import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Places a phone call directly (native ACTION_CALL) so an SOS can ring the
/// emergency contact without the user tapping the dialer. Mirrors the
/// "com.sina.mobility/call" MethodChannel in MainActivity.kt.
class CallService {
  static const MethodChannel _ch = MethodChannel('com.sina.mobility/call');

  /// Request CALL_PHONE up front so the SOS path isn't blocked by a prompt.
  Future<bool> requestPermission() async =>
      (await Permission.phone.request()).isGranted;

  /// Dial [phone] directly. Returns false if permission is missing or the call
  /// could not be placed (caller can then fall back to the dialer). Never throws.
  Future<bool> call(String phone) async {
    if (phone.trim().isEmpty) return false;
    try {
      if (!await Permission.phone.request().isGranted) return false;
      final ok = await _ch.invokeMethod<bool>('call', {'phone': phone.trim()});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
