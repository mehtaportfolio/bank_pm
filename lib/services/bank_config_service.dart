class BankConfig {
  final String name;
  final String balanceEnquiryNumber;

  BankConfig({required this.name, required this.balanceEnquiryNumber});
}

class BankConfigService {
  static final List<BankConfig> banks = [
    BankConfig(name: 'SBI', balanceEnquiryNumber: '09223766666'),
    BankConfig(name: 'Axis Bank', balanceEnquiryNumber: '18004195959'),
    BankConfig(name: 'PNB', balanceEnquiryNumber: '18001802223'),
  ];
}
