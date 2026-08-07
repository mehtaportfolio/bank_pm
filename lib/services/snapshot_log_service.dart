import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SnapshotLog {
  final String message;
  final DateTime timestamp;
  final String? bank;
  final bool isError;

  SnapshotLog({
    required this.message,
    required this.timestamp,
    this.bank,
    this.isError = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'bank': bank,
      'isError': isError,
    };
  }

  factory SnapshotLog.fromJson(Map<String, dynamic> json) {
    return SnapshotLog(
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      bank: json['bank'],
      isError: json['isError'] ?? false,
    );
  }
}

class SnapshotLogService {
  static const String _logKey = 'monthly_snapshot_logs';
  static const String _lastRunKey = 'last_monthly_run';

  static Future<void> log(String message, {String? bank, bool isError = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final logsJson = prefs.getStringList(_logKey) ?? [];
    
    final logEntry = SnapshotLog(
      message: message,
      timestamp: DateTime.now(),
      bank: bank,
      isError: isError,
    );
    
    logsJson.add(jsonEncode(logEntry.toJson()));
    
    // Keep only last 100 logs
    if (logsJson.length > 100) {
      logsJson.removeAt(0);
    }
    
    await prefs.setStringList(_logKey, logsJson);
  }

  static Future<List<SnapshotLog>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Force reload to see changes from background isolate
    final logsJson = prefs.getStringList(_logKey) ?? [];
    return logsJson.map((e) => SnapshotLog.fromJson(jsonDecode(e))).toList().reversed.toList();
  }

  static Future<void> setLastRunDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastRunKey, date.toIso8601String());
  }

  static Future<DateTime?> getLastRunDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Force reload to see changes from background isolate
    final dateStr = prefs.getString(_lastRunKey);
    return dateStr != null ? DateTime.parse(dateStr) : null;
  }

  static Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logKey);
  }

  static Future<Map<String, bool>> getBankStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Force reload to see changes from background isolate
    final logsJson = prefs.getStringList(_logKey) ?? [];
    final logs = logsJson.map((e) => SnapshotLog.fromJson(jsonDecode(e))).toList();
    final lastRun = await getLastRunDate();
    
    if (lastRun == null) return {};

    Map<String, bool> statuses = {};
    // Consider logs from 1 minute before last run to be safe
    final startTime = lastRun.subtract(const Duration(minutes: 1));
    final threshold = lastRun.add(const Duration(hours: 24));
    
    for (var log in logs) {
      if (log.timestamp.isAfter(startTime) && log.timestamp.isBefore(threshold)) {
        if (log.bank != null) {
          if (log.message.contains('upload result: Success')) {
            statuses[log.bank!] = true;
          } else if (log.isError) {
            // Only set to false if not already success
            if (statuses[log.bank!] != true) {
              statuses[log.bank!] = false;
            }
          }
        }
      }
    }
    return statuses;
  }
}
