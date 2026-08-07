import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bank_balance_snapshot.dart';
import 'snapshot_log_service.dart';

class SnapshotUploadService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> uploadSnapshot(BankBalanceSnapshot snapshot) async {
    try {
      // Using upsert to respect unique_bank_account constraint (bank_name, account_number)
      // and update the balance and captured_at if it already exists.
      await _supabase
          .from('bank_balance_snapshots')
          .upsert(
            snapshot.toJson(),
            onConflict: 'bank_name, account_number',
          );
      
      await SnapshotLogService.log(
        'upload result: Success',
        bank: snapshot.bankName,
      );
      
    } catch (e) {
      await SnapshotLogService.log(
        'upload result: Error - $e',
        bank: snapshot.bankName,
        isError: true,
      );
      rethrow;
    }
  }
}
