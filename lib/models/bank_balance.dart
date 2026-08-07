class BankBalance {
  final String bank;
  final double balance;
  final DateTime messageDate;
  final String sender;
  final String smsBody;
  final String? accountSuffix;
  final String? accountNumber;
  final bool isSnapshot;

  BankBalance({
    required this.bank,
    required this.balance,
    required this.messageDate,
    required this.sender,
    required this.smsBody,
    this.accountSuffix,
    this.accountNumber,
    this.isSnapshot = false,
  });
}
