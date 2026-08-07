import 'package:telephony/telephony.dart';
import 'balance_parser.dart';
import '../models/bank_balance_snapshot.dart';
import 'snapshot_log_service.dart';

class MonthlySmsRefreshService {
  final Telephony _telephony = Telephony.instance;

  Future<List<BankBalanceSnapshot>> getMonthlySnapshots(DateTime since) async {
    await SnapshotLogService.log('SMS refresh started');
    
    List<SmsMessage> messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    Map<String, BankBalanceSnapshot> latestSnapshots = {};

    for (var sms in messages) {
      final date = sms.date != null 
          ? DateTime.fromMillisecondsSinceEpoch(sms.date!) 
          : DateTime.now();

      // Only consider messages after the request was sent
      if (date.isBefore(since)) continue;

      final body = sms.body ?? '';
      final sender = sms.address ?? '';

      // Ignore OTP and Promotional
      if (BalanceParser.isPromotional(body)) continue;

      final bank = BalanceParser.identifyBank(sender, body);
      if (bank == null) continue;

      await SnapshotLogService.log('SMS identified for bank', bank: bank);

      // Detect balance info
      final parsedResults = BalanceParser.parseBalances(body);
      
      if (parsedResults.isEmpty) {
         await SnapshotLogService.log('No balance parsed from SMS', bank: bank, isError: true);
      }
      
      for (var result in parsedResults) {
        String accNum = result.accountNumber ?? "Unknown";
        String key = "${bank}_$accNum";
        
        // Since messages are DESC, first one is latest
        if (!latestSnapshots.containsKey(key)) {
          latestSnapshots[key] = BankBalanceSnapshot(
            bankName: bank,
            accountNumber: result.accountNumber,
            balance: result.balance,
            capturedAt: date,
          );
        }
      }
    }

    final snapshots = latestSnapshots.values.toList();
    await SnapshotLogService.log('balances extracted: ${snapshots.length} found');
    return snapshots;
  }
}
