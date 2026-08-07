import 'package:flutter_test/flutter_test.dart';
import 'package:bank/models/bank_balance_snapshot.dart';
import 'package:bank/utils/bank_snapshot_grouping.dart';

void main() {
  test('groups snapshots by bank name into sections', () {
    final snapshots = <BankBalanceSnapshot>[
      BankBalanceSnapshot(
        bankName: 'SBI',
        accountNumber: '1234',
        balance: 1000,
        capturedAt: DateTime(2024, 1, 1),
      ),
      BankBalanceSnapshot(
        bankName: 'AXIS',
        accountNumber: '9876',
        balance: 2000,
        capturedAt: DateTime(2024, 1, 2),
      ),
      BankBalanceSnapshot(
        bankName: 'SBI',
        accountNumber: '5678',
        balance: 1500,
        capturedAt: DateTime(2024, 1, 3),
      ),
      BankBalanceSnapshot(
        bankName: 'PNB',
        accountNumber: '2468',
        balance: 3000,
        capturedAt: DateTime(2024, 1, 4),
      ),
    ];

    final sections = groupBankSnapshotsByBankName(snapshots);

    expect(sections.map((section) => section.bankName), ['AXIS', 'PNB', 'SBI']);
    expect(sections[2].snapshots.map((snapshot) => snapshot.accountNumber), ['1234', '5678']);
  });
}
