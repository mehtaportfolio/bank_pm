import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum TaxCalculationMode {
  monthly,
  annual,
}

class TaxScreen extends StatefulWidget {
  const TaxScreen({super.key});

  @override
  State<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends State<TaxScreen> {
  final _monthlyController = TextEditingController();
  final _annualController = TextEditingController();

  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  final TaxCalculationMode _defaultMode = TaxCalculationMode.monthly;
  TaxCalculationMode _mode = TaxCalculationMode.monthly;

  // Inputs as numbers (null = not entered)
  int? _monthlyGrossSalary;
  int? _annualGrossSalary;

  // Computation outputs
  TaxComputationResult? _result;

  static const int standardDeduction = 75000;
  static const int rebateThresholdTaxable = 1200000; // ₹12,00,000 taxable income

  @override
  void initState() {
    super.initState();
    _mode = _defaultMode;

    _monthlyController.addListener(_onAnyInputChanged);
    _annualController.addListener(_onAnyInputChanged);
  }

  @override
  void dispose() {
    _monthlyController.dispose();
    _annualController.dispose();
    super.dispose();
  }

  void _onAnyInputChanged() {
    final monthlyValue = _parseNonNegativeInt(_monthlyController.text);
    final annualValue = _parseNonNegativeInt(_annualController.text);

    setState(() {
      _monthlyGrossSalary = monthlyValue;
      _annualGrossSalary = annualValue;
    });

    _recompute();
  }

  void _recompute() {
    final monthlyEntered = _monthlyGrossSalary;
    final annualEntered = _annualGrossSalary;

    if (_mode == TaxCalculationMode.monthly) {
      if (monthlyEntered == null) {
        setState(() => _result = null);
        return;
      }

      final annualGrossSalary = monthlyEntered * 12;
      // Sync the disabled annual field.
      setState(() {
        _annualGrossSalary = annualGrossSalary;
        _annualController.text = annualGrossSalary.toString();
      });

      final computed = TaxCalculatorNewRegimeFY2526.compute(
        annualGrossSalary: annualGrossSalary,
        standardDeduction: standardDeduction,
        rebateThresholdTaxable: rebateThresholdTaxable,
      );
      setState(() => _result = computed);
      return;
    }

    // Annual mode
    if (annualEntered == null) {
      setState(() => _result = null);
      return;
    }

    final computed = TaxCalculatorNewRegimeFY2526.compute(
      annualGrossSalary: annualEntered,
      standardDeduction: standardDeduction,
      rebateThresholdTaxable: rebateThresholdTaxable,
    );

    setState(() => _result = computed);
  }

  int? _parseNonNegativeInt(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return null;

    final value = int.tryParse(digitsOnly);
    if (value == null) return null;
    if (value < 0) return null;

    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Calculator'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildModeSelector(theme),
            const SizedBox(height: 16),
            _buildInputSection(),
            const SizedBox(height: 16),
            if (_result == null)
              const Text('Enter gross salary to calculate tax.')
            else ...[
              _buildSummaryCard(_result!),
              const SizedBox(height: 16),
              _buildSlabBreakdownCard(_result!),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(ThemeData theme) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calculation mode',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<TaxCalculationMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: TaxCalculationMode.monthly,
                  label: Text('Monthly Gross Salary'),
                  icon: Icon(Icons.calendar_month),
                ),
                ButtonSegment(
                  value: TaxCalculationMode.annual,
                  label: Text('Annual Gross Salary'),
                  icon: Icon(Icons.date_range),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (Set<TaxCalculationMode> newSelection) {
                final newMode = newSelection.first;
                setState(() {
                  _mode = newMode;
                });
                _recompute();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    final isMonthly = _mode == TaxCalculationMode.monthly;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMonthly ? 'Monthly Gross Salary' : 'Annual Gross Salary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: isMonthly ? _monthlyController : _annualController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: isMonthly
                    ? 'Enter monthly gross salary'
                    : 'Enter annual gross salary',
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              inputFormatters: const [],
              onSubmitted: (_) => _recompute(),
            ),
            const SizedBox(height: 12),
            if (isMonthly) _buildDisabledAnnualField() else _buildDisabledMonthlyField(),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledAnnualField() {
    final monthlyEntered = _parseNonNegativeInt(_monthlyController.text);
    final derivedAnnual = monthlyEntered == null ? null : (monthlyEntered * 12);

    return TextField(
      controller: TextEditingController(
        text: derivedAnnual == null ? '' : derivedAnnual.toString(),
      ),
      enabled: false,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        prefixText: '₹ ',
        hintText: 'Auto-calculated',
        labelText: 'Annual Gross Salary',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _buildDisabledMonthlyField() {
    final annualEntered = _parseNonNegativeInt(_annualController.text);
    final derivedMonthly = annualEntered == null ? null : (annualEntered / 12).floor();

    return TextField(
      enabled: false,
      controller: TextEditingController(
        text: derivedMonthly == null ? '' : derivedMonthly.toString(),
      ),
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        prefixText: '₹ ',
        hintText: 'Derived from annual',
        labelText: 'Monthly Gross Salary',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _buildSummaryCard(TaxComputationResult r) {
    final monthlyTds = r.finalTaxPayable / 12;
    final effectiveRate = r.annualTaxableIncome == 0
        ? 0.0
        : (r.finalTaxPayable / r.annualTaxableIncome) * 100;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tax Summary',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _summaryRow(
              label: 'Gross Salary',
              value: _currency.format(r.annualGrossSalary),
            ),
            _summaryRow(
              label: 'Standard Deduction',
              value: _currency.format(r.standardDeduction),
            ),
            _summaryRow(
              label: 'Taxable Income',
              value: _currency.format(r.annualTaxableIncome),
            ),
            const Divider(height: 24),
            _summaryRow(
              label: 'Tax Before Cess',
              value: _currency.format(r.taxBeforeCess.round()),
            ),
            _summaryRow(
              label: 'Cess Amount (4%)',
              value: _currency.format(r.cessAmount.round()),
            ),
            if (r.marginalReliefAmount > 0)
              _summaryRow(
                label: 'Marginal Relief Amount',
                value: _currency.format(r.marginalReliefAmount.round()),
              ),
            if (r.marginalReliefAmount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: Text(
                  'Marginal Relief Applied – Tax restricted to excess income above ₹12 lakh.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.orange,
                  ),
                ),
              ),
            const Divider(height: 24),
            _summaryRow(
              label: 'Final Tax Payable',
              value: _currency.format(r.finalTaxPayable.round()),
              valueStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.green,
              ),
            ),
            const Divider(height: 24),
            _summaryRow(
              label: 'Monthly TDS (Final Tax / 12)',
              value: _currency.format(monthlyTds.round()),
            ),
            _summaryRow(
              label: 'Effective Tax Rate (%)',
              value: '${effectiveRate.toStringAsFixed(2)}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow({
    required String label,
    required String value,
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: valueStyle ??
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildSlabBreakdownCard(TaxComputationResult r) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text(
          'Slab-wise Tax Breakdown',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...r.slabBreakdown.map(
                  (s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _slabRow(s),
                  ),
                ),
                const Divider(height: 24),
                Text(
                  'Section 87A Rebate: ${r.section87ARebateApplied ? 'Applied' : 'Not applied'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tax after 87A (before marginal relief): ${_currency.format(r.taxAfter87A.round())}',
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _slabRow(SlabTax s) {
    final amountStr = _currency.format(s.taxableInSlab);
    final taxStr = _currency.format(s.taxAmount.round());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${s.slabLabel} @ ${s.ratePercent.toStringAsFixed(0)}%',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Taxable portion: $amountStr',
              style: const TextStyle(color: Colors.black54),
            ),
            Text(
              'Tax: $taxStr',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ],
    );
  }
}

class TaxComputationResult {
  TaxComputationResult({
    required this.annualGrossSalary,
    required this.standardDeduction,
    required this.annualTaxableIncome,
    required this.taxBeforeCess,
    required this.taxAfter87A,
    required this.cessAmount,
    required this.marginalReliefAmount,
    required this.finalTaxPayable,
    required this.slabBreakdown,
    required this.section87ARebateApplied,
  });

  final int annualGrossSalary;
  final int standardDeduction;
  final int annualTaxableIncome;

  /// Tax before adding cess, after applying section 87A rebate.
  final double taxBeforeCess;

  /// Tax after 87A rebate, before marginal relief.
  final double taxAfter87A;

  final double cessAmount;
  final double marginalReliefAmount;
  final double finalTaxPayable;

  final List<SlabTax> slabBreakdown;
  final bool section87ARebateApplied;
}

class SlabTax {
  SlabTax({
    required this.slabLabel,
    required this.ratePercent,
    required this.taxableInSlab,
    required this.taxAmount,
  });

  final String slabLabel;
  final double ratePercent;
  final int taxableInSlab;
  final double taxAmount;
}

class TaxCalculatorNewRegimeFY2526 {
  // FY 2025-26 New Tax Regime slabs as per request.
  // Rates are applied on annual taxable income.

  static TaxComputationResult compute({
    required int annualGrossSalary,
    required int standardDeduction,
    required int rebateThresholdTaxable,
  }) {
    // Calculation order (as required): Gross Salary -> minus Standard Deduction -> Taxable Income.
    int annualTaxableIncome = annualGrossSalary - standardDeduction;
    if (annualTaxableIncome < 0) {
      annualTaxableIncome = 0;
    }

    debugPrint('Gross Salary: $annualGrossSalary');
    debugPrint('Standard Deduction: $standardDeduction');
    debugPrint('Taxable Income: $annualTaxableIncome');


    final slabs = <({int from, int toExclusive, double rate, String label})>[
      (from: 0, toExclusive: 400000, rate: 0, label: '0 – 4,00,000'),
      (from: 400000, toExclusive: 800000, rate: 5, label: '4,00,001 – 8,00,000'),
      (from: 800000, toExclusive: 1200000, rate: 10, label: '8,00,001 – 12,00,000'),
      (from: 1200000, toExclusive: 1600000, rate: 15, label: '12,00,001 – 16,00,000'),
      (from: 1600000, toExclusive: 2000000, rate: 20, label: '16,00,001 – 20,00,000'),
      (from: 2000000, toExclusive: 2400000, rate: 25, label: '20,00,001 – 24,00,000'),
      (from: 2400000, toExclusive: 1 << 62, rate: 30, label: 'Above 24,00,000'),
    ];

    double taxBefore87A = 0;
    final breakdown = <SlabTax>[];

    for (final s in slabs) {
      final taxableInSlab = _clampAnnualPortion(annualTaxableIncome, s.from, s.toExclusive);
      final taxAmount = taxableInSlab <= 0 ? 0.0 : taxableInSlab * (s.rate / 100);
      taxBefore87A += taxAmount;

      breakdown.add(
        SlabTax(
          slabLabel: s.label,
          ratePercent: s.rate,
          taxableInSlab: taxableInSlab,
          taxAmount: taxAmount,
        ),
      );
    }

    // Section 87A rebate
    // If annual taxable income <= 12,00,000 then total tax payable should be ₹0.
    final section87ARebateApplied = annualTaxableIncome <= rebateThresholdTaxable;
    final taxAfter87A = section87ARebateApplied ? 0.0 : taxBefore87A;

    // Marginal Relief (apply first on tax AFTER 87A, then compute cess).
    // Per requirement: totalNetTax = taxBeforeCess - marginal relief.
    final excessIncome = annualTaxableIncome - rebateThresholdTaxable;

    double marginalReliefAmount = 0;
    if (annualTaxableIncome > rebateThresholdTaxable && taxAfter87A > excessIncome) {
      // final tax payable (before cess re-computation) is capped by excessIncome.
      // marginal relief reduces taxAfter87A down to excessIncome.
      marginalReliefAmount = (taxAfter87A - excessIncome.toDouble()).clamp(0.0, taxAfter87A);
    }

    final totalNetTax = (taxAfter87A - marginalReliefAmount).clamp(0.0, taxAfter87A);

    // Health & Education Cess: 4% on total net tax (after marginal relief).
    final cessAmount = totalNetTax * 0.04;

    final finalTaxPayable = totalNetTax + cessAmount;

    return TaxComputationResult(
      annualGrossSalary: annualGrossSalary,
      standardDeduction: standardDeduction,
      annualTaxableIncome: annualTaxableIncome,
      taxBeforeCess: taxAfter87A,
      taxAfter87A: taxAfter87A,
      cessAmount: cessAmount,
      marginalReliefAmount: marginalReliefAmount,
      finalTaxPayable: finalTaxPayable,
      slabBreakdown: breakdown,
      section87ARebateApplied: section87ARebateApplied,
    );
  }

  static int _clampAnnualPortion(int income, int fromInclusive, int toExclusive) {
    final upper = income < toExclusive ? income : toExclusive;
    final portion = upper - fromInclusive;
    if (portion <= 0) return 0;

    final maxPortion = toExclusive - fromInclusive;
    return portion > maxPortion ? maxPortion : portion;
  }
}

