import '../models/bank_balance_snapshot.dart';

class BankSnapshotSection {
  final String bankName;
  final List<BankBalanceSnapshot> snapshots;

  const BankSnapshotSection({
    required this.bankName,
    required this.snapshots,
  });
}

List<BankSnapshotSection> groupBankSnapshotsByBankName(
  List<BankBalanceSnapshot> snapshots,
) {
  final groupedSnapshots = <String, List<BankBalanceSnapshot>>{};

  for (final snapshot in snapshots) {
    final bankName = snapshot.bankName.trim().isEmpty ? 'Unknown' : snapshot.bankName.trim();
    groupedSnapshots.putIfAbsent(bankName, () => []).add(snapshot);
  }

  final sortedEntries = groupedSnapshots.entries.toList()
    ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

  return sortedEntries.map((entry) {
    final sortedSnapshots = List<BankBalanceSnapshot>.from(entry.value)
      ..sort((a, b) {
        final accountCompare = (a.accountNumber ?? '').toLowerCase().compareTo(
          (b.accountNumber ?? '').toLowerCase(),
        );
        if (accountCompare != 0) {
          return accountCompare;
        }
        return a.capturedAt.compareTo(b.capturedAt);
      });

    return BankSnapshotSection(
      bankName: entry.key,
      snapshots: sortedSnapshots,
    );
  }).toList();
}
