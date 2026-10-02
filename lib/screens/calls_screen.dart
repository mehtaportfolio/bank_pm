import 'package:flutter/material.dart';
import '../services/bank_call_number_service.dart';
import '../services/call_service.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  final BankCallNumberService _bankCallNumberService = BankCallNumberService();
  final CallService _callService = CallService();
  final Map<int, String> _phoneNumbers = {
    45: '18004195959',
    48: '18001802223',
    49: '09223766666',
  };
  int? _savingBankId;

  static const List<_BankCallInfo> _banks = [
    _BankCallInfo(id: 45, name: 'AXIS', bankName: 'AXIS', color: Color(0xFF971C44)),
    _BankCallInfo(id: 48, name: 'PNB', bankName: 'PNB-MP', color: Color(0xFFE41E26)),
    _BankCallInfo(id: 49, name: 'SBI', bankName: 'SBI', color: Color(0xFF0054A6)),
  ];

  @override
  void initState() {
    super.initState();
    _loadPhoneNumbers();
  }

  Future<void> _loadPhoneNumbers() async {
    try {
      final savedNumbers = await _bankCallNumberService.fetchPhoneNumbers();
      if (mounted) {
        setState(() => _phoneNumbers.addAll(savedNumbers));
      }
    } catch (error) {
      debugPrint('Could not load saved call numbers: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load saved phone numbers. Using defaults.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _banks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final bank = _banks[index];
        final phoneNumber = _phoneNumbers[bank.id]!;
        return _BankCallCard(
          name: bank.name,
          number: phoneNumber,
          color: bank.color,
          isSaving: _savingBankId == bank.id,
          onEditPressed: () => _editPhoneNumber(bank, phoneNumber),
          onCallPressed: () => _showConfirmDialog(bank.name, phoneNumber),
        );
      },
    );
  }

  Future<void> _editPhoneNumber(_BankCallInfo bank, String currentNumber) async {
    final TextEditingController controller = TextEditingController(text: currentNumber);
    String? validationError;
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Edit phone number'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '${bank.name} number',
                errorText: validationError,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final number = controller.text.trim().replaceAll(RegExp(r'[\s()-]'), '');
                  if (!RegExp(r'^\+?\d{5,15}$').hasMatch(number)) {
                    setDialogState(() => validationError = 'Enter a valid phone number.');
                    return;
                  }
                  Navigator.of(context).pop(number);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();

    if (result == null || !mounted) return;

    setState(() => _savingBankId = bank.id);
    try {
      await _bankCallNumberService.savePhoneNumber(
        id: bank.id,
        bankName: bank.bankName,
        phoneNumber: result,
      );
      if (mounted) {
        setState(() => _phoneNumbers[bank.id] = result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${bank.name} phone number saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save ${bank.name} phone number: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingBankId = null);
    }
  }

  Future<void> _showConfirmDialog(String bankName, String phoneNumber) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Call'),
          content: Text(
            'This will open the dialer to request the latest account balance from $bankName.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final bool success = await _callService.openDialer(phoneNumber);
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open dialer for $bankName ($phoneNumber)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _BankCallInfo {
  final int id;
  final String name;
  final String bankName;
  final Color color;

  const _BankCallInfo({
    required this.id,
    required this.name,
    required this.bankName,
    required this.color,
  });
}

class _BankCallCard extends StatelessWidget {
  final String name;
  final String number;
  final Color color;
  final bool isSaving;
  final VoidCallback onEditPressed;
  final VoidCallback onCallPressed;

  const _BankCallCard({
    required this.name,
    required this.number,
    required this.color,
    required this.isSaving,
    required this.onEditPressed,
    required this.onCallPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color,
              child: Text(
                name[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Number: $number',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: isSaving ? null : onEditPressed,
                  icon: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit),
                  tooltip: 'Edit $name phone number',
                ),
                IconButton.filled(
                  onPressed: onCallPressed,
                  icon: const Icon(Icons.call),
                  style: IconButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.all(12),
                  ),
                  tooltip: 'Call $name',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
