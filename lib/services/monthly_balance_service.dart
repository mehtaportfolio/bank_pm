import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'bank_config_service.dart';
import 'monthly_sms_refresh_service.dart';
import 'snapshot_upload_service.dart';
import 'snapshot_log_service.dart';

class MonthlyBalanceService {
  final MonthlySmsRefreshService _smsRefreshService = MonthlySmsRefreshService();
  final SnapshotUploadService _uploadService = SnapshotUploadService();

  Future<void> initiateBankRequests() async {
    await SnapshotLogService.log('bank request started');
    
    for (var bank in BankConfigService.banks) {
      try {
        await SnapshotLogService.log('Initiating call', bank: bank.name);
        bool? res = await FlutterPhoneDirectCaller.callNumber(bank.balanceEnquiryNumber);
        if (res == false) {
          await SnapshotLogService.log('Call failed or permission denied', bank: bank.name, isError: true);
        }
        // Wait a bit between calls to avoid overlapping or system issues
        await Future.delayed(const Duration(seconds: 15));
      } catch (e) {
        await SnapshotLogService.log('Error during call: $e', bank: bank.name, isError: true);
      }
    }
  }

  Future<void> runSnapshotProcess(DateTime since) async {
    try {
      final snapshots = await _smsRefreshService.getMonthlySnapshots(since);
      
      if (snapshots.isEmpty) {
        await SnapshotLogService.log('No SMS received after 4 hours', isError: true);
      }

      for (var snapshot in snapshots) {
        try {
          await _uploadService.uploadSnapshot(snapshot);
        } catch (e) {
          // Individual upload errors are logged in the upload service
        }
      }
    } catch (e) {
      await SnapshotLogService.log('Critical error in snapshot process: $e', isError: true);
    }
  }
}
