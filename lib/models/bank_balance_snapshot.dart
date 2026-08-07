class BankBalanceSnapshot {
  final int? id;
  final String bankName;
  final String? accountNumber;
  final double balance;
  final DateTime capturedAt;

  BankBalanceSnapshot({
    this.id,
    required this.bankName,
    this.accountNumber,
    required this.balance,
    required this.capturedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'bank_name': bankName,
      'account_number': accountNumber,
      'balance': balance,
      'captured_at': capturedAt.toIso8601String(),
    };
  }

  factory BankBalanceSnapshot.fromJson(Map<String, dynamic> json) {
    return BankBalanceSnapshot(
      id: json['id'],
      bankName: json['bank_name'],
      accountNumber: json['account_number'],
      balance: (json['balance'] as num).toDouble(),
      capturedAt: DateTime.parse(json['captured_at']),
    );
  }
}
