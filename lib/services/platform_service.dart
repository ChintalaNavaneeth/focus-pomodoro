import 'package:flutter/services.dart';

class PlatformService {
  static const MethodChannel _channel = MethodChannel('com.antigravity.pomodoro/lock');

  static Future<bool> startFocus(int durationSeconds, int backgroundColor, int accentColor) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('startFocus', {
        'duration_seconds': durationSeconds,
        'background_color': backgroundColor,
        'accent_color': accentColor,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to start focus session: ${e.message}");
      return false;
    }
  }

  static Future<bool> stopFocus() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('stopFocus');
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to stop focus session: ${e.message}");
      return false;
    }
  }

  static Future<bool> isFocusRunning() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('isFocusRunning');
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to check if focus running: ${e.message}");
      return false;
    }
  }

  static Future<int> getSecondsRemaining() async {
    try {
      final int? result = await _channel.invokeMethod<int>('getSecondsRemaining');
      return result ?? 0;
    } on PlatformException catch (e) {
      print("Failed to get seconds remaining: ${e.message}");
      return 0;
    }
  }

  static Future<bool> hasOverlayPermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to check overlay permission: ${e.message}");
      return false;
    }
  }

  static Future<bool> hasVpnPermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('hasVpnPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to check VPN permission: ${e.message}");
      return false;
    }
  }

  static Future<bool> hasPhonePermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('hasPhonePermission');
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to check Phone permission: ${e.message}");
      return false;
    }
  }

  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on PlatformException catch (e) {
      print("Failed to request overlay permission: ${e.message}");
    }
  }

  static Future<void> requestVpnPermission() async {
    try {
      await _channel.invokeMethod('requestVpnPermission');
    } on PlatformException catch (e) {
      print("Failed to request VPN permission: ${e.message}");
    }
  }

  static Future<void> requestPhonePermission() async {
    try {
      await _channel.invokeMethod('requestPhonePermission');
    } on PlatformException catch (e) {
      print("Failed to request Phone permission: ${e.message}");
    }
  }

  static Future<bool> hasDeviceAdmin() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('hasDeviceAdmin');
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to check device admin: ${e.message}");
      return false;
    }
  }

  static Future<void> requestDeviceAdmin() async {
    try {
      await _channel.invokeMethod('requestDeviceAdmin');
    } on PlatformException catch (e) {
      print("Failed to request device admin: ${e.message}");
    }
  }

  static Future<bool> hasAccessibilityPermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('hasAccessibilityPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to check Accessibility permission: ${e.message}");
      return false;
    }
  }

  static Future<void> requestAccessibilityPermission() async {
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
    } on PlatformException catch (e) {
      print("Failed to request Accessibility permission: ${e.message}");
    }
  }

  static Future<bool> hasUsageStatsPermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('hasUsageStatsPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to check Usage Stats permission: ${e.message}");
      return false;
    }
  }

  static Future<void> requestUsageStatsPermission() async {
    try {
      await _channel.invokeMethod('requestUsageStatsPermission');
    } on PlatformException catch (e) {
      print("Failed to request Usage Stats permission: \${e.message}");
    }
  }
}
