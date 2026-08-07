import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bank_balance.dart';
import '../models/bank_balance_snapshot.dart';
import '../services/sms_service.dart';
import '../services/total_bank_balance_service.dart';
import '../utils/bank_snapshot_grouping.dart';
import 'calls_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SmsService _smsService = SmsService();
  final TotalBankBalanceService _totalBankBalanceService = TotalBankBalanceService();
  final SupabaseClient _supabase = Supabase.instance.client;
  List<BankBalance> _balances = [];
  List<BankBalanceSnapshot> _bankSnapshots = [];
  double? _totalBankBalance;
  bool _isLoading = false;
  bool _isBankLoading = false;
  bool _isSaving = false;
  bool _isTotalLoading = true;
  String? _errorMessage;
  String? _bankErrorMessage;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  Future<void> _fetchTotalBankBalance() async {
    setState(() {
      _isTotalLoading = true;
    });

    try {
      final total = await _totalBankBalanceService.fetchTotalBalance();
      if (mounted) {
        setState(() {
          _totalBankBalance = total;
          _isTotalLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching total bank balance: $e');
      if (mounted) {
        setState(() {
          _totalBankBalance = null;
          _isTotalLoading = false;
        });
      }
    }
  }

  Future<void> _fetchBalances() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final status = await Permission.sms.request();
      if (!status.isGranted) {
        setState(() {
          _errorMessage = 'SMS Permission denied';
          _isLoading = false;
        });
        return;
      }

      final results = await _smsService.getLatestBankBalances();
      final supplementalBalances = await _fetchSupplementalSnapshotBalances();

      results.sort((a, b) {
        int bankCompare = a.bank.compareTo(b.bank);
        if (bankCompare != 0) return bankCompare;
        return (a.accountNumber ?? '').compareTo(b.accountNumber ?? '');
      });
      supplementalBalances.sort((a, b) {
        int bankCompare = a.bank.compareTo(b.bank);
        if (bankCompare != 0) return bankCompare;
        return (a.accountNumber ?? '').compareTo(b.accountNumber ?? '');
      });

      if (mounted) {
        setState(() {
          _balances = [...results, ...supplementalBalances];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error fetching balances: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _clearBalances() {
    setState(() {
      _balances = [];
    });
  }

  Future<void> _saveToSupabase() async {
    if (_balances.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final dataToSave = _balances.map((b) {
        return {
          'bank_name': b.bank,
          'account_number': b.accountNumber ?? b.accountSuffix ?? 'Unknown',
          'balance': b.balance,
          'captured_at': b.messageDate.toIso8601String(),
        };
      }).toList();

      await _supabase
          .from('bank_balance_snapshots')
          .upsert(dataToSave, onConflict: 'bank_name,account_number');
      await _fetchTotalBankBalance();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Balances saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error saving to Supabase: $e';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving to Supabase: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<List<BankBalance>> _fetchSupplementalSnapshotBalances() async {
    final response = await _supabase
        .from('bank_balance_snapshots')
        .select()
        .filter('id', 'in', '(6,7)');

    final items = response as List<dynamic>;

    return items.map((item) {
      final bank = item['bank_name']?.toString() ?? 'Unknown';
      final accountNumber = item['account_number']?.toString();
      final balanceValue = item['balance'];
      final capturedAt = item['captured_at'];

      final balance = balanceValue is num
          ? balanceValue.toDouble()
          : double.tryParse(balanceValue?.toString() ?? '') ?? 0.0;
      final messageDate = capturedAt != null
          ? DateTime.parse(capturedAt.toString())
          : DateTime.now();

      return BankBalance(
        bank: bank,
        balance: balance,
        messageDate: messageDate,
        sender: 'Snapshot ID-${item['id']}',
        smsBody: 'Supabase snapshot entry',
        accountNumber: accountNumber,
        isSnapshot: true,
      );
    }).toList();
  }

  Future<void> _fetchBankSnapshots() async {
    setState(() {
      _isBankLoading = true;
      _bankErrorMessage = null;
    });

    try {
      final response = await _supabase
          .from('bank_balance_snapshots')
          .select()
          .order('captured_at', ascending: false);

      final items = response as List<dynamic>;
      final snapshots = items
          .map((item) => BankBalanceSnapshot.fromJson(item as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _bankSnapshots = snapshots;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bankErrorMessage = 'Error loading bank snapshots: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBankLoading = false;
        });
      }
    }
  }

  Future<void> _deleteBankSnapshot(int snapshotId) async {
    try {
      await _supabase
          .from('bank_balance_snapshots')
          .delete()
          .eq('id', snapshotId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Snapshot deleted successfully.')),
        );
      }
      await _fetchBankSnapshots();
      await _fetchTotalBankBalance();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete snapshot: $e')),
        );
      }
    }
  }

  Future<void> _showEditSnapshotDialog(int snapshotId) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SnapshotEditDialog(snapshotId: snapshotId),
    );

    if (saved == true) {
      await _fetchBalances();
      await _fetchBankSnapshots();
      await _fetchTotalBankBalance();
    }
  }

  Future<void> _confirmDeleteSnapshot(int snapshotId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bank Snapshot'),
        content: const Text('Are you sure you want to delete this bank snapshot?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteBankSnapshot(snapshotId);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchTotalBankBalance();
    _fetchBalances();
    _fetchBankSnapshots();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bank Balance Reader'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.call), text: 'Call'),
              Tab(icon: Icon(Icons.sms), text: 'SMS'),
              Tab(icon: Icon(Icons.account_balance), text: 'Bank'),
            ],
          ),
          actions: [
            if (_balances.isNotEmpty)
              IconButton(
                onPressed: _isSaving ? null : _saveToSupabase,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                tooltip: 'Save to Supabase',
              ),
            IconButton(
              onPressed: _clearBalances,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear List',
            ),
            IconButton(
              onPressed: _fetchBalances,
              icon: const Icon(Icons.refresh),
              tooltip: 'Fetch Latest',
            ),
          ],
        ),
        body: Column(
          children: [
            _TotalBankBalanceBanner(
              total: _totalBankBalance,
              isLoading: _isTotalLoading,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const CallsScreen(),
                  Column(
                    children: [
                      _SnapshotButtons(onButtonPressed: _showEditSnapshotDialog),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _errorMessage != null
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _errorMessage!,
                                          style: const TextStyle(color: Colors.red),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: _fetchBalances,
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: () async {
                                      await _fetchBalances();
                                      await _fetchTotalBankBalance();
                                    },
                                    child: _balances.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'No bank balances found for today.',
                                            ),
                                          )
                                        : ListView.builder(
                                            padding: const EdgeInsets.all(16),
                                            itemCount: _balances.length,
                                            itemBuilder: (context, index) {
                                              final balance = _balances[index];
                                              return _BankBalanceCard(
                                                bankBalance: balance,
                                              );
                                            },
                                          ),
                                  ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Bank Snapshots',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              onPressed: _fetchBankSnapshots,
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Reload bank snapshots',
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _isBankLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _bankErrorMessage != null
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _bankErrorMessage!,
                                          style: const TextStyle(color: Colors.red),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: _fetchBankSnapshots,
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: _fetchBankSnapshots,
                                    child: _bankSnapshots.isEmpty
                                        ? const Center(
                                            child: Text('No bank snapshots found.'),
                                          )
                                        : LayoutBuilder(
                                            builder: (context, constraints) {
                                              final sections = groupBankSnapshotsByBankName(_bankSnapshots);
                                              final isNarrow = constraints.maxWidth < 720;
                                              if (isNarrow) {
                                                return ListView.separated(
                                                  padding: const EdgeInsets.all(16),
                                                  itemCount: sections.length,
                                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                                  itemBuilder: (context, sectionIndex) {
                                                    final section = sections[sectionIndex];
                                                    return Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Container(
                                                          width: double.infinity,
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                          decoration: BoxDecoration(
                                                            color: Colors.orange,
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Text(
                                                            section.bankName,
                                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                              fontWeight: FontWeight.w700,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        ...section.snapshots.map((snapshot) {
                                                          return Padding(
                                                            padding: const EdgeInsets.only(bottom: 8),
                                                            child: Card(
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                              elevation: 2,
                                                              child: Padding(
                                                                padding: const EdgeInsets.all(16),
                                                                child: Row(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Expanded(
                                                                      child: Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                          Text(
                                                                            _dateFormat.format(snapshot.capturedAt.toLocal()),
                                                                            style: const TextStyle(
                                                                              fontSize: 14,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                          ),
                                                                          const SizedBox(height: 8),
                                                                          Text('Account: ${snapshot.accountNumber ?? 'Unknown'}'),
                                                                          Text('Balance: ₹${snapshot.balance.toStringAsFixed(2)}'),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    IconButton(
                                                                      onPressed: snapshot.id != null
                                                                          ? () => _showEditSnapshotDialog(snapshot.id!)
                                                                          : null,
                                                                      icon: const Icon(Icons.edit),
                                                                      tooltip: 'Edit',
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        }),
                                                      ],
                                                    );
                                                  },
                                                );
                                              }

                                              return ListView(
                                                padding: const EdgeInsets.all(16),
                                                children: [
                                                  ...sections.map((section) {
                                                    return Padding(
                                                      padding: const EdgeInsets.only(bottom: 16),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Container(
                                                            width: double.infinity,
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                            decoration: BoxDecoration(
                                                              color: Colors.orange,
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Text(
                                                              section.bankName,
                                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                                fontWeight: FontWeight.w700,
                                                                color: Colors.white,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 8),
                                                          SingleChildScrollView(
                                                            scrollDirection: Axis.horizontal,
                                                            child: DataTable(
                                                              columnSpacing: 24,
                                                              columns: const [
                                                                DataColumn(label: Text('Date')),
                                                                DataColumn(label: Text('Account Number')),
                                                                DataColumn(label: Text('Balance')),
                                                                DataColumn(label: Text('Actions')),
                                                              ],
                                                              rows: section.snapshots.map((snapshot) {
                                                                final snapshotId = snapshot.id;
                                                                return DataRow(cells: [
                                                                  DataCell(Text(_dateFormat.format(snapshot.capturedAt.toLocal()))),
                                                                  DataCell(Text(snapshot.accountNumber ?? 'Unknown')),
                                                                  DataCell(Text('₹${snapshot.balance.toStringAsFixed(2)}')),
                                                                  DataCell(Row(
                                                                    children: [
                                                                      IconButton(
                                                                        onPressed: snapshotId != null
                                                                            ? () => _showEditSnapshotDialog(snapshotId)
                                                                            : null,
                                                                        icon: const Icon(Icons.edit),
                                                                        tooltip: 'Edit',
                                                                        visualDensity: VisualDensity.compact,
                                                                      ),
                                                                    ],
                                                                  )),
                                                                ]);
                                                              }).toList(),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }),
                                                  const SizedBox(height: 16),
                                                ],
                                              );
                                            },
                                          ),
                                  ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalBankBalanceBanner extends StatelessWidget {
  final double? total;
  final bool isLoading;

  const _TotalBankBalanceBanner({required this.total, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Total Bank Balance',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              total == null ? 'Unavailable' : '₹${total!.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
        ],
      ),
    );
  }
}

class _SnapshotButtons extends StatelessWidget {
  final void Function(int) onButtonPressed;

  const _SnapshotButtons({required this.onButtonPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
              ),
              onPressed: () => onButtonPressed(6),
              child: const Text('PDM'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
                foregroundColor: Colors.white,
              ),
              onPressed: () => onButtonPressed(7),
              child: const Text('BDM'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotEditDialog extends StatefulWidget {
  final int snapshotId;

  const _SnapshotEditDialog({required this.snapshotId});

  @override
  State<_SnapshotEditDialog> createState() => _SnapshotEditDialogState();
}

class _SnapshotEditDialogState extends State<_SnapshotEditDialog> {
  late Future<Map<String, dynamic>?> _snapshotFuture;
  final TextEditingController _balanceController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _fetchSnapshotById(widget.snapshotId);
  }

  Future<Map<String, dynamic>?> _fetchSnapshotById(int snapshotId) async {
    final response = await Supabase.instance.client
        .from('bank_balance_snapshots')
        .select()
        .eq('id', snapshotId)
        .maybeSingle();

    if (response is Map<String, dynamic>) {
      return response;
    }
    return null;
  }

  Future<void> _updateSnapshotBalance(int id, double balance) async {
    await Supabase.instance.client
        .from('bank_balance_snapshots')
        .update({'balance': balance})
        .eq('id', id);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Snapshot ID-${widget.snapshotId}'),
      content: FutureBuilder<Map<String, dynamic>?>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Text('Error loading snapshot: ${snapshot.error}');
          }

          final snapshotData = snapshot.data;
          if (snapshotData == null) {
            return const Text('Snapshot not found for this ID.');
          }

          _balanceController.text = snapshotData['balance']?.toString() ?? '';

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildReadOnlyField('ID', widget.snapshotId.toString()),
              const SizedBox(height: 8),
              _buildReadOnlyField('Bank Name', snapshotData['bank_name']?.toString() ?? ''),
              const SizedBox(height: 8),
              _buildReadOnlyField('Account Number', snapshotData['account_number']?.toString() ?? ''),
              const SizedBox(height: 8),
              TextField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Balance',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              _buildReadOnlyField('Captured At', snapshotData['captured_at']?.toString() ?? ''),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSaving
              ? null
              : () async {
                  final balanceText = _balanceController.text.trim();
                  final parsedBalance = double.tryParse(balanceText);
                  if (parsedBalance == null) {
                    setState(() {
                      _errorMessage = 'Enter a valid numeric balance.';
                    });
                    return;
                  }

                  setState(() {
                    _isSaving = true;
                    _errorMessage = null;
                  });

                  try {
                    await _updateSnapshotBalance(widget.snapshotId, parsedBalance);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Snapshot updated successfully.')),
                      );
                    }
                    Navigator.of(context).pop(true);
                  } catch (e) {
                    setState(() {
                      _errorMessage = 'Failed to update snapshot: $e';
                    });
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isSaving = false;
                      });
                    }
                  }
                },
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return TextField(
      readOnly: true,
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _BankBalanceCard extends StatelessWidget {
  final BankBalance bankBalance;

  const _BankBalanceCard({required this.bankBalance});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(
                        children: [
                          Text(
                            bankBalance.bank,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (bankBalance.isSnapshot)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blueGrey.shade200),
                              ),
                              child: const Text(
                                'Snapshot',
                                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                              ),
                            ),
                        ],
                      ),
                    Text(
                      'A/c: ${bankBalance.accountNumber ?? 'Unknown'}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
                Text(
                  '₹${bankBalance.balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Sender: ${bankBalance.sender}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Date: ${bankBalance.messageDate.toLocal()}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
