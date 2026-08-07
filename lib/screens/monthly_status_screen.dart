import 'package:flutter/material.dart';
import '../services/snapshot_log_service.dart';
import '../services/bank_config_service.dart';
import 'package:intl/intl.dart';

import '../services/monthly_balance_service.dart';
import '../services/monthly_scheduler_service.dart';
import 'package:workmanager/workmanager.dart';
import '../models/bank_balance_snapshot.dart';
import '../services/total_bank_balance_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MonthlyStatusScreen extends StatefulWidget {
  const MonthlyStatusScreen({super.key});

  @override
  State<MonthlyStatusScreen> createState() => _MonthlyStatusScreenState();
}

class _MonthlyStatusScreenState extends State<MonthlyStatusScreen> {
  final TotalBankBalanceService _totalBalanceService =
      TotalBankBalanceService();
  DateTime? _lastRun;
  Map<String, bool> _bankStatuses = {};
  Map<String, double> _bankBalances = {};
  List<SnapshotLog> _logs = [];
  List<BankBalanceSnapshot> _snapshots = [];

  String _maskAccount(String? acct) {
    if (acct == null || acct.isEmpty) return '';
    if (acct.length <= 3) return acct;
    return 'xx${acct.substring(acct.length - 3)}';
  }
  double? _totalBankBalance;
  bool _isLoading = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _runManualTest() async {
    setState(() => _isTesting = true);
    try {
      await SnapshotLogService.log('Manual test trigger started');
      final now = DateTime.now();
      await SnapshotLogService.setLastRunDate(now);

      final service = MonthlyBalanceService();
      await service.initiateBankRequests();

      // Schedule the processor task for 1 minute later for quick testing
      await Workmanager().registerOneOffTask(
        "manual_test_processor_${now.millisecondsSinceEpoch}",
        MonthlySchedulerService.taskProcess,
        initialDelay: const Duration(minutes: 1),
        inputData: {'request_time': now.toIso8601String()},
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Test initiated! Calls started. SMS processing scheduled for 1 minute from now.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Test failed: $e')));
      }
    } finally {
      await _refreshData();
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final lastRun = await SnapshotLogService.getLastRunDate();
    final logStatuses = await SnapshotLogService.getBankStatuses();
    final logs = await SnapshotLogService.getLogs();
    double? totalBankBalance;

    try {
      totalBankBalance = await _totalBalanceService.fetchTotalBalance();
    } catch (e) {
      debugPrint('Error fetching total bank balance: $e');
    }

    Map<String, bool> finalStatuses = Map.from(logStatuses);
    Map<String, double> balances = {};

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final tomorrowStart = todayStart.add(const Duration(days: 1));

      final response = await Supabase.instance.client
          .from('bank_balance_snapshots')
          .select()
          .gte('captured_at', todayStart.toUtc().toIso8601String())
          .lt('captured_at', tomorrowStart.toUtc().toIso8601String());

      final List<BankBalanceSnapshot> snapshots = [];
      for (var item in response as List<dynamic>) {
        final snapshot = BankBalanceSnapshot.fromJson(item);
        snapshots.add(snapshot);
        finalStatuses[snapshot.bankName] = true;
        // keep a bank-level balance for backward compatibility
        balances[snapshot.bankName] = snapshot.balance;
      }

      _snapshots = snapshots;
    } catch (e) {
      debugPrint('Error checking Supabase for today\'s snapshots: $e');
    }

    if (mounted) {
      setState(() {
        _lastRun = lastRun;
        _bankStatuses = finalStatuses;
        _bankBalances = balances;
          _logs = logs;
          _snapshots = _snapshots;
        _totalBankBalance = totalBankBalance;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Snapshot Status'),
        actions: [
          if (_isTesting)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _runManualTest,
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Run Test Now',
            ),
          IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTotalBankBalanceBanner(),
                  const SizedBox(height: 16),
                  _buildStatusSection(),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Execution Logs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await SnapshotLogService.clearLogs();
                          await _refreshData();
                        },
                        icon: const Icon(
                          Icons.delete_sweep,
                          color: Colors.redAccent,
                        ),
                        tooltip: 'Clear Logs',
                      ),
                    ],
                  ),
                  const Divider(),
                  ..._logs.map(
                    (log) => ListTile(
                      dense: true,
                      title: Text(log.message),
                      subtitle: Text(
                        '${DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp)}${log.bank != null ? ' - ${log.bank}' : ''}',
                      ),
                      leading: Icon(
                        log.isError ? Icons.error_outline : Icons.info_outline,
                        color: log.isError ? Colors.red : Colors.blue,
                      ),
                    ),
                  ),
                  if (_logs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('No logs available')),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Monthly Run: ${_lastRun != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_lastRun!) : 'Never'}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (_snapshots.isNotEmpty)
              ..._snapshots.map((snapshot) {
                final masked = _maskAccount(snapshot.accountNumber);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${snapshot.bankName} (${masked})',
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              '₹${snapshot.balance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                );
              }),
            if (_snapshots.isEmpty)
              ...BankConfigService.banks.map((bank) {
                final status = _bankStatuses[bank.name];
                final balance = _bankBalances[bank.name];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${bank.name}:',
                              style: const TextStyle(fontSize: 16),
                            ),
                            if (balance != null)
                              Text(
                                '₹${balance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            status == true
                                ? 'Success'
                                : (status == false ? 'Failed' : 'Pending'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: status == true
                                  ? Colors.green
                                  : (status == false
                                        ? Colors.red
                                        : Colors.orange),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            status == true
                                ? Icons.check_circle
                                : (status == false ? Icons.error : Icons.pending),
                            color: status == true
                                ? Colors.green
                                : (status == false ? Colors.red : Colors.orange),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBankBalanceBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          Text(
            _totalBankBalance == null
                ? 'Unavailable'
                : '₹${_totalBankBalance!.toStringAsFixed(2)}',
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
