import 'package:flutter/material.dart';
import '../services/call_service.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CallService callService = CallService();

    final List<Map<String, String>> banks = [
      {
        'name': 'AXIS',
        'number': '18004195959',
        'color': '0xFF971C44',
      },
      {
        'name': 'PNB',
        'number': '18001802223',
        'color': '0xFFE41E26',
      },
      {
        'name': 'SBI',
        'number': '09223766666',
        'color': '0xFF0054A6',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: banks.map((bank) {
        return _BankCallCard(
          name: bank['name']!,
          number: bank['number']!,
          color: Color(int.parse(bank['color']!)),
          onCallPressed: () => _showConfirmDialog(context, bank['name']!, bank['number']!, callService),
        );
      }).toList(),
    );
  }

  Future<void> _showConfirmDialog(
    BuildContext context,
    String bankName,
    String phoneNumber,
    CallService callService,
  ) async {
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
      final bool success = await callService.openDialer(phoneNumber);
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

class _BankCallCard extends StatelessWidget {
  final String name;
  final String number;
  final Color color;
  final VoidCallback onCallPressed;

  const _BankCallCard({
    required this.name,
    required this.number,
    required this.color,
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
      ),
    );
  }
}
