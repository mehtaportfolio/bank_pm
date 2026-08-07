import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'monthly_balance_service.dart';
import 'monthly_retry_manager.dart';
import 'snapshot_log_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Initialize Supabase if not already
      try {
        Supabase.instance.client;
      } catch (e) {
        await Supabase.initialize(
          url: 'https://ifisogduvyerncltqulc.supabase.co',
          anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlmaXNvZ2R1dnllcm5jbHRxdWxjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0MTUwMzEsImV4cCI6MjA3MDk5MTAzMX0.Z6m5wQjcllZD_76GGv9thzjEmjMXH1y6IZUaZ2r1toI',
        );
      }

      final monthlyBalanceService = MonthlyBalanceService();

      if (task == MonthlySchedulerService.taskTrigger) {
        await SnapshotLogService.log('scheduler started');

        // Run once per day (avoid duplicates if WorkManager retries / overlaps)
        final now = DateTime.now();
        final lastRun = await SnapshotLogService.getLastRunDate();
        if (lastRun != null &&
            lastRun.year == now.year &&
            lastRun.month == now.month &&
            lastRun.day == now.day) {
          return Future.value(true);
        }

        await SnapshotLogService.setLastRunDate(now);
        try {
          await monthlyBalanceService.initiateBankRequests();
        } catch (e) {
          // If direct calling fails (often happens when device is locked/backgrounded),
          // prompt user to open app to retry.
          await SnapshotLogService.log('initiateBankRequests failed: $e', isError: true);
          await MonthlyRetryManager.markRetryPending(requestTime: DateTime.now());
          await MonthlyRetryManager.showRetryNotification(requestTime: DateTime.now());
          return Future.value(true);
        }


        
        // Schedule the processor task for 4 hours later
        await Workmanager().registerOneOffTask(
          "monthly_processor_${now.millisecondsSinceEpoch}",
          MonthlySchedulerService.taskProcess,
          initialDelay: const Duration(hours: 4),
          inputData: {'request_time': now.toIso8601String()},
          existingWorkPolicy: ExistingWorkPolicy.replace,
        );

      } else if (task == MonthlySchedulerService.taskProcess) {
        final requestTimeStr = inputData?['request_time'];
        final requestTime = requestTimeStr != null 
            ? DateTime.parse(requestTimeStr) 
            : DateTime.now().subtract(const Duration(hours: 4));
            
        await monthlyBalanceService.runSnapshotProcess(requestTime);
      }

      return Future.value(true);
    } catch (e) {
      await SnapshotLogService.log('WorkManager Error: $e', isError: true);
      return Future.value(false);
    }
  });
}

class MonthlySchedulerService {
  static const String taskTrigger = "monthly_balance_trigger";
  static const String taskProcess = "monthly_balance_process";

  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  static Future<void> scheduleMonthlyTask() async {
    // Schedule the trigger to run once per day around 6:00 AM.
    // WorkManager periodic tasks have a minimum flex/accuracy, so we compute the next 6am and
    // then use a 24h periodic task.

    final now = DateTime.now();

    // Next occurrence of 10:00 local time
    DateTime nextRun = DateTime(now.year, now.month, now.day, 10, 0);

    if (now.isAfter(nextRun)) {
      nextRun = nextRun.add(const Duration(days: 1));
    }

    final delay = nextRun.difference(now);

    // One-off: align to the next 10am
    await Workmanager().registerOneOffTask(
      "daily_trigger_scheduler",
      taskTrigger,
      initialDelay: delay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    // Periodic: keep running every 24h as a fallback/ensurer
    await Workmanager().registerPeriodicTask(
      "daily_check",
      taskTrigger,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );

  }
}

