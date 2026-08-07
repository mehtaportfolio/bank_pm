import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TotalBankBalanceService {
  static const Set<int> _excludedSnapshotIds = {48, 49};

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<double> fetchTotalBalance() async {
    final response = await _supabase
        .from('bank_balance_snapshots')
        .select('id,balance');

    double total = 0;

    for (final item in response) {
      if (item is! Map) continue;

      final id = _parseId(item['id']);
      if (id != null && _excludedSnapshotIds.contains(id)) continue;

      final rawBalance = item['balance'];
      final balance = _parseBalance(rawBalance);
      if (balance == null) {
        debugPrint('Skipping invalid balance value: $rawBalance');
        continue;
      }

      total += balance;
    }

    return total;
  }

  int? _parseId(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _parseBalance(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', ''));
    return null;
  }
}
