import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'local_notification_service.dart';
import 'monthly_balance_service.dart';
import 'snapshot_log_service.dart';


class MonthlyRetryManager {
  static const String _retryFlagKey = 'monthly_retry_pending';
  static const String _retryRequestTimeKey = 'monthly_retry_request_time';

  static bool _inProgress = false;

  static Future<void> markRetryPending({required DateTime requestTime}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_retryFlagKey, true);
    await prefs.setString(_retryRequestTimeKey, requestTime.toIso8601String());
  }

  static Future<void> clearRetryPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_retryFlagKey, false);
    await prefs.remove(_retryRequestTimeKey);
  }

  static Future<bool> isRetryPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_retryFlagKey) ?? false;
  }

  static Future<void> handleNotificationPayload(String? payload) async {
    if (payload == null) return;

    try {
      final parsed = await _tryParseJson(payload);
      if (parsed == null) return;
      if (parsed['type'] != 'monthly_retry') return;

      final requestTimeStr = parsed['request_time'];
      final requestTime = requestTimeStr != null
          ? DateTime.tryParse(requestTimeStr)
          : DateTime.now().subtract(const Duration(hours: 4));

      if (requestTime == null) return;

      await retryNow(requestTime: requestTime);
    } catch (e) {
      await SnapshotLogService.log('Monthly retry payload handling error: $e', isError: true);
    }
  }


  static Future<Map<String, dynamic>?> _tryParseJson(String s) async {
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }


  static Future<void> retryNow({required DateTime requestTime}) async {
    if (_inProgress) return;
    _inProgress = true;

    try {
      await SnapshotLogService.log('User opened app to retry monthly process', isError: false);
      // Clear early to avoid loops.
      await clearRetryPending();

      final service = MonthlyBalanceService();
      await service.initiateBankRequests();
      await service.runSnapshotProcess(requestTime);
    } catch (e) {
      await SnapshotLogService.log('Monthly retryNow failed: $e', isError: true);
    } finally {
      _inProgress = false;
    }
  }

  static Future<void> maybeRetryFromAppLaunch() async {
    if (await isRetryPending()) {
      await SnapshotLogService.log('Monthly retry pending detected on app launch');
      // Do not auto-run immediately without user tap? Requirement says: when app is opened then retry.
      // We'll retry right away upon opening.
      final prefs = await SharedPreferences.getInstance();
      final requestTimeStr = prefs.getString(_retryRequestTimeKey);
      final requestTime = requestTimeStr != null
          ? DateTime.tryParse(requestTimeStr) ?? DateTime.now().subtract(const Duration(hours: 4))
          : DateTime.now().subtract(const Duration(hours: 4));

      await retryNow(requestTime: requestTime);
    }
  }

  static Future<void> showRetryNotification({required DateTime requestTime}) async {
    final notif = LocalNotificationService();
    await notif.showMonthlyRetryNotification(
      id: 9901,
      title: 'Monthly process failed',
      body: 'Tap to retry bank calls and snapshot processing.',
      payload: {
        'type': 'monthly_retry',
        'request_time': requestTime.toIso8601String(),
      },
    );
  }
}

