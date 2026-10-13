import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/cost_calculator.dart';
import '../../../core/utils/formatters.dart';

class EnergyCalculatorScreen extends ConsumerStatefulWidget {
  const EnergyCalculatorScreen({super.key});

  @override
  ConsumerState<EnergyCalculatorScreen> createState() =>
      _EnergyCalculatorScreenState();
}

class _EnergyCalculatorScreenState
    extends ConsumerState<EnergyCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();

  final _distanceCtrl = TextEditingController(text: '120.0');
  final _electricKwhCtrl = TextEditingController(text: '18.0');
  final _petrolLitersCtrl = TextEditingController(text: '2.5');
  late TextEditingController _tariffCtrl;
  late TextEditingController _petrolPriceCtrl;
  final _chargingLossCtrl = TextEditingController(text: '10');

  TripCostResult? _calculationResult;

  @override
  void initState() {
    super.initState();
    final energy = ref.read(energyStateProvider);
    _tariffCtrl = TextEditingController(
      text: energy.defaultTariffPerKwh.toStringAsFixed(3),
    );
    _petrolPriceCtrl = TextEditingController(
      text: energy.defaultPetrolPricePerLiter.toStringAsFixed(2),
    );

    // Initial calculation
    _runCalculation();
  }

  @override
  void dispose() {
    _distanceCtrl.dispose();
    _electricKwhCtrl.dispose();
    _petrolLitersCtrl.dispose();
    _tariffCtrl.dispose();
    _petrolPriceCtrl.dispose();
    _chargingLossCtrl.dispose();
    super.dispose();
  }

  void _runCalculation() {
    final dist = double.tryParse(_distanceCtrl.text) ?? 100.0;
    final kwh = double.tryParse(_electricKwhCtrl.text) ?? 0.0;
    final l = double.tryParse(_petrolLitersCtrl.text) ?? 0.0;
    final tariff = double.tryParse(_tariffCtrl.text) ?? 0.516;
    final petrolPrice = double.tryParse(_petrolPriceCtrl.text) ?? 2.05;
    final lossPct = double.tryParse(_chargingLossCtrl.text) ?? 10.0;

    if (dist <= 0 || tariff <= 0 || petrolPrice <= 0) return;

    try {
      final inputs = TripCostInputs(
        distanceKm: dist,
        electricEnergyKwh: kwh,
        fuelLiters: l,
        electricityTariffPerKwh: tariff,
        petrolPricePerLiter: petrolPrice,
        chargingLossFraction: lossPct / 100.0,
      );

      setState(() {
        _calculationResult = CostCalculator.calculateTripCost(inputs);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Calculation error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Energy & Cost Calculator')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Deterministic Disclaimer Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.calculate_outlined,
                    color: AppTheme.primaryTeal,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Deterministic mathematical calculation grounded in TNB and Malaysian RON95 rates. No AI-hallucinated figures.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Input Fields Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TRIP & CONSUMPTION INPUTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _distanceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Distance Travelled (km)',
                        suffixText: 'km',
                      ),
                      onChanged: (_) => _runCalculation(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _electricKwhCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Electricity Used',
                              suffixText: 'kWh',
                            ),
                            onChanged: (_) => _runCalculation(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _petrolLitersCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Petrol Used',
                              suffixText: 'Litres',
                            ),
                            onChanged: (_) => _runCalculation(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _tariffCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'TNB Tariff / kWh',
                              prefixText: 'RM ',
                            ),
                            onChanged: (_) => _runCalculation(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _petrolPriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Petrol Price / L',
                              prefixText: 'RM ',
                            ),
                            onChanged: (_) => _runCalculation(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _chargingLossCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'AC Charging Losses (OBC Conversion)',
                        suffixText: '%',
                      ),
                      onChanged: (_) => _runCalculation(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Results Card
            if (_calculationResult != null)
              _buildResultCard(_calculationResult!),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(TripCostResult res) {
    return Card(
      color: AppTheme.elevatedCard,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CALCULATED COST BREAKDOWN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Trip Cost',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      Formatters.formatCurrency(res.totalCostRm),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Cost Per 100 km',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      Formatters.formatCurrency(res.costPer100KmRm),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            _buildResultRow(
              'Electricity Cost',
              Formatters.formatCurrency(res.electricityCostRm),
            ),
            _buildResultRow(
              'Petrol Cost',
              Formatters.formatCurrency(res.petrolCostRm),
            ),
            _buildResultRow(
              'Cost per Kilometre',
              Formatters.formatCurrency(res.costPerKmRm),
            ),
            _buildResultRow(
              'Pure Petrol Baseline (6.5L/100km)',
              Formatters.formatCurrency(res.equivalentPurePetrolCostRm),
            ),
            _buildResultRow(
              'PHEV Savings this Trip',
              Formatters.formatCurrency(res.savingsVersusPurePetrolRm),
              highlight: true,
            ),
            const SizedBox(height: 14),
            const Text(
              'Calculation Assumptions & Units:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 4),
            ...res.assumptions.map(
              (a) => Text(
                '• $a',
                style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: highlight ? AppTheme.statusLive : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
