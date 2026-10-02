import 'package:supabase_flutter/supabase_flutter.dart';

class BankCallNumberService {
  static const Map<int, String> _expectedBankNames = {
    45: 'AXIS',
    48: 'PNB-MP',
    49: 'SBI',
  };

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<int, String>> fetchPhoneNumbers() async {
    final rows = await _supabase
        .from('user_master')
        .select('id, bank_name, pran_number')
        .inFilter('id', _expectedBankNames.keys.toList());

    final Map<int, String> phoneNumbers = {};
    for (final row in rows) {
      final int? id = int.tryParse(row['id'].toString());
      if (id == null) continue;

      final expectedBankName = _expectedBankNames[id];
      if (expectedBankName == null || row['bank_name'] != expectedBankName) {
        continue;
      }

      final phoneNumber = row['pran_number']?.toString().trim();
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        phoneNumbers[id] = phoneNumber;
      }
    }

    return phoneNumbers;
  }

  Future<void> savePhoneNumber({
    required int id,
    required String bankName,
    required String phoneNumber,
  }) async {
    if (_expectedBankNames[id] != bankName) {
      throw ArgumentError('Unexpected bank for user_master row $id.');
    }

    final updatedRows = await _supabase
        .from('user_master')
        .update({'pran_number': phoneNumber})
        .eq('id', id)
        .eq('bank_name', bankName)
        .select('id');

    if (updatedRows.isEmpty) {
      throw StateError('No matching $bankName row found for ID $id.');
    }
  }
}