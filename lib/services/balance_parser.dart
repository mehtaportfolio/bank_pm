class BalanceResult {
  final double balance;
  final String? accountSuffix;
  final String? accountNumber;

  BalanceResult({required this.balance, this.accountSuffix, this.accountNumber});
}

class BalanceParser {
  static List<BalanceResult> parseBalances(String body) {
    List<BalanceResult> results = [];
    
    // 1. Extract all possible account numbers from the text
    // Handles: A/c XX1234, A/c xxx1234, A/c XXXXX031613, A/c no. 1234, A/C:1234, A/c no. XX7242
    final RegExp accRegex = RegExp(r'A/c[^\d]*?([xX\d]+)', caseSensitive: false, dotAll: true);
    final Iterable<RegExpMatch> accMatches = accRegex.allMatches(body);
    
    List<String> foundAccounts = [];
    for (var m in accMatches) {
      String raw = m.group(1)!;
      // Extract digits only for suffixing if it's mostly digits, otherwise keep as is if it has XX
      String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (raw.toUpperCase().contains('XX') && digits.length >= 3) {
        foundAccounts.add(raw.toUpperCase());
      } else if (digits.length >= 3) {
        String suffix = digits.length > 4 ? digits.substring(digits.length - 4) : digits;
        // Keep original prefix if it has X, otherwise use XX
        String prefix = raw.toUpperCase().startsWith('X') ? raw.substring(0, raw.lastIndexOf('X') + 1).toUpperCase() : 'XX';
        foundAccounts.add('$prefix$suffix');
      }
    }

    // 2. Check for PNB multiple accounts format: A/c XX2300:INR8057.99
    final RegExp pnbMultiPattern = RegExp(
      r'A/c[^\d]*?(\d+):(?:INR|Rs|Rs\.)\s*([\d,]+\.?\d*)',
      caseSensitive: false,
      dotAll: true,
    );

    final Iterable<RegExpMatch> pnbMatches = pnbMultiPattern.allMatches(body);
    if (pnbMatches.isNotEmpty) {
      for (final match in pnbMatches) {
        String suffix = match.group(1)!;
        String amountString = match.group(2)!;
        double? amount = double.tryParse(amountString.replaceAll(',', ''));
        if (amount != null) {
          results.add(BalanceResult(
            balance: amount, 
            accountSuffix: suffix,
            accountNumber: 'XX$suffix',
          ));
        }
      }
      return results;
    }

    // 3. Default balance extraction with improved keywords
    final RegExp balanceRegex = RegExp(
      r'(?:balance|bal|available|avl|account balance|avail bal).*?(?:INR|Rs|Rs\.)\s*([\d,]+\.?\d*)',
      caseSensitive: false,
      dotAll: true,
    );

    final match = balanceRegex.firstMatch(body);
    if (match != null) {
      String amountString = match.group(1)!;
      double? amount = double.tryParse(amountString.replaceAll(',', ''));
      if (amount != null) {
        String? bestAcc = foundAccounts.isNotEmpty ? foundAccounts.first : null;
        results.add(BalanceResult(
          balance: amount,
          accountNumber: bestAcc,
        ));
      }
    }

    return results;
  }

  static String? identifyBank(String sender, String body) {
    final s = sender.toUpperCase();
    final b = body.toUpperCase();
    
    if (s.contains('SBI') || s.contains('CBSSBI') || s.contains('STBK') || b.contains('STATE BANK OF INDIA') || b.contains(' SBI ')) return 'SBI';
    if (s.contains('PNB') || s.contains('PUNJAB') || s.contains('PNBSMS') || b.contains('PUNJAB NATIONAL BANK') || b.contains(' PNB ')) return 'PNB';
    if (s.contains('AXIS') || s.contains('AXISBK') || s.contains('UTIB') || b.contains('AXIS BANK')) return 'Axis Bank';
    
    return null;
  }

  static bool isPromotional(String body) {
    final bodyLower = body.toLowerCase();
    
    // Keywords indicating balance info
    final balanceKeywords = ['balance', 'bal', 'available', 'avl', 'a/c', 'account', 'inr', 'rs.'];
    bool hasBalanceInfo = balanceKeywords.any((keyword) => bodyLower.contains(keyword));
    
    if (hasBalanceInfo) {
      // Prioritize balance info even if links are present, but still filter OTPs
      // Only treat as promotional if it's an OTP
      return bodyLower.contains('otp');
    }

    final promoKeywords = ['offer', 'win', 'cashback', 'click', 'apply', 'limited time', 'benefit'];
    return promoKeywords.any((keyword) => bodyLower.contains(keyword));
  }
}
