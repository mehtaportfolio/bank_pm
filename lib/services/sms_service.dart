import 'package:telephony/telephony.dart';
import '../models/bank_balance.dart';
import 'balance_parser.dart';

class SmsService {
  final Telephony _telephony = Telephony.instance;

  Future<List<BankBalance>> getLatestBankBalances() async {
    List<SmsMessage> messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    // Filter for today's messages
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Initial pass to collect all potential balances
    List<BankBalance> allFoundBalances = [];

    for (var sms in messages) {
      final date = sms.date != null 
          ? DateTime.fromMillisecondsSinceEpoch(sms.date!) 
          : DateTime.now();

      // 1. Check if message is from today
      final messageDate = DateTime(date.year, date.month, date.day);
      if (messageDate.isBefore(today)) continue;

      final sender = sms.address ?? '';
      final body = sms.body ?? '';

      // 2. Identify Bank (Filter for Axis, SBI, PNB)
      final bank = BalanceParser.identifyBank(sender, body);
      if (bank == null) continue;

      // 3. Extract Balances
      final parsedResults = BalanceParser.parseBalances(body);
      
      for (var result in parsedResults) {
        allFoundBalances.add(BankBalance(
          bank: bank,
          balance: result.balance,
          messageDate: date,
          sender: sender,
          smsBody: body,
          accountSuffix: result.accountSuffix,
          accountNumber: result.accountNumber,
        ));
      }
    }

    // 4. Intelligent Deduplication
    // Group by Bank and Last 3 digits of account number
    Map<String, BankBalance> finalBalances = {};

    for (var balance in allFoundBalances) {
      String accNum = balance.accountNumber ?? "Unknown";
      String last3 = accNum.length >= 3 
          ? accNum.substring(accNum.length - 3) 
          : accNum;
      
      String key = "${balance.bank}_$last3";
      
      // Since allFoundBalances follows the DESC order of messages,
      // the first one we see for a key is the latest.
      if (!finalBalances.containsKey(key)) {
        finalBalances[key] = balance;
      }
    }

    return finalBalances.values.toList();
  }
}
