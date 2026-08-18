import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this for LogicalKeyboardKey
import 'create_entry_dialog_base.dart';
import '../enums/report_type.dart';
import '../services/apiservice.dart';

class PurchaseCreateEntryDialog extends StatefulWidget {
  final bool isModify;
  final Map<String, dynamic>? existingData;

  const PurchaseCreateEntryDialog({
    super.key,
    this.isModify = false,
    this.existingData,
  });

  @override
  State<PurchaseCreateEntryDialog> createState() =>
      _PurchaseCreateEntryDialogState();
}

class _PurchaseCreateEntryDialogState
    extends CreateEntryDialogState<PurchaseCreateEntryDialog> {
  // Purchase-specific fields
  final farmersDayController = TextEditingController();
  final farmersProgressiveController = TextEditingController();
  final dayArrivalsApmcController = TextEditingController();
  final dayArrivalsOutsideController = TextEditingController();
  final progArrivalsApmcController = TextEditingController();
  final progArrivalsOutsideController = TextEditingController();
  final marketRateHighestController = TextEditingController();
  final marketRateLowestController = TextEditingController();
  final marketRateAverageController = TextEditingController();
  final marketSeedRateHighestController = TextEditingController();
  final marketSeedRateLowestController = TextEditingController();
  final cciPurchaseQtlsController = TextEditingController();
  final cciPurchaseBalesController = TextEditingController();
  final cciKapasMoistureController = TextEditingController();
  final mspValueDayController = TextEditingController();
  final mspValueProgController = TextEditingController();
  final cciRateHighestController = TextEditingController();
  final cciRateLowestController = TextEditingController();
  final cciRateAverageController = TextEditingController();
  final cciSeedRateController = TextEditingController();
  final cciOutTurnController = TextEditingController();
  final cciShortageController = TextEditingController();
  final cciExpensesController = TextEditingController();
  final processingCycleController = TextEditingController();
  final cciPadthaController = TextEditingController();
  final progPurchaseQtlsController = TextEditingController();
  final progPurchaseBalesController = TextEditingController();
  final progPadthaController = TextEditingController();
  final progAvgRateController = TextEditingController();
  final balesPressedTodayController = TextEditingController();
  final balesPressedProgController = TextEditingController();
  final totalBalesShiftedController = TextEditingController();
  final sampleSentController = TextEditingController();
  final heapResultController = TextEditingController();

  List<PurchaseFactoryData> purchaseFactories = [];
  String? selectedVariety;
  bool isLoadingPreviousProgressive = false;
  String debugMessage = '';

  double previousProgApmc = 0;
  double previousProgOutside = 0;
  double previousFarmersProg = 0;
  double previousMspProg = 0;
  double previousBalesProg = 0;

  final List<String> varieties = [
    'BB MOD',
    'H-4',
    'DCH-32',
    'Suvin',
    'J-34',
    'LRA',
  ];

  @override
  ReportType get reportType => ReportType.dailyPurchase;
  @override
  String get reportTypeLabel => 'Purchase';
  @override
  Color get accentColor => const Color(0xFFE0F2FE);
  @override
  IconData get iconData => Icons.shopping_basket_rounded;
  @override
  String get routeKey => 'purchase';

  @override
  void initState() {
    super.initState();
    if (!widget.isModify) {
      dayArrivalsApmcController.addListener(_recalculateProgApmc);
      dayArrivalsOutsideController.addListener(_recalculateProgOutside);
      farmersDayController.addListener(_recalculateFarmersProg);
      mspValueDayController.addListener(_recalculateMspProg);
      balesPressedTodayController.addListener(_recalculateBalesProg);
    }
  }

  @override
  void dispose() {
    farmersDayController.dispose();
    farmersProgressiveController.dispose();
    dayArrivalsApmcController.dispose();
    dayArrivalsOutsideController.dispose();
    progArrivalsApmcController.dispose();
    progArrivalsOutsideController.dispose();
    marketRateHighestController.dispose();
    marketRateLowestController.dispose();
    marketRateAverageController.dispose();
    marketSeedRateHighestController.dispose();
    marketSeedRateLowestController.dispose();
    cciPurchaseQtlsController.dispose();
    cciPurchaseBalesController.dispose();
    cciKapasMoistureController.dispose();
    mspValueDayController.dispose();
    mspValueProgController.dispose();
    cciRateHighestController.dispose();
    cciRateLowestController.dispose();
    cciRateAverageController.dispose();
    cciSeedRateController.dispose();
    cciOutTurnController.dispose();
    cciShortageController.dispose();
    cciExpensesController.dispose();
    processingCycleController.dispose();
    cciPadthaController.dispose();
    progPurchaseQtlsController.dispose();
    progPurchaseBalesController.dispose();
    progPadthaController.dispose();
    progAvgRateController.dispose();
    balesPressedTodayController.dispose();
    balesPressedProgController.dispose();
    totalBalesShiftedController.dispose();
    sampleSentController.dispose();
    heapResultController.dispose();
    super.dispose();
  }

  @override
  void loadExistingData(Map<String, dynamic> data) {
    final centre = data['centre'] as String?;
    selectedCentre = (centre != null && centre.isNotEmpty) ? centre : null;
    reportNoController.text = data['reportNo']?.toString() ?? '';
    moistureController.text = data['moisture'] ?? '';
    farmersDayController.text = data['farmersDay']?.toString() ?? '';
    farmersProgressiveController.text = data['farmersProgressive']?.toString() ?? '';
    dayArrivalsApmcController.text = data['dayArrivalsApmc']?.toString() ?? '';
    dayArrivalsOutsideController.text = data['dayArrivalsOutside']?.toString() ?? '';
    progArrivalsApmcController.text = data['progArrivalsApmc']?.toString() ?? '';
    progArrivalsOutsideController.text = data['progArrivalsOutside']?.toString() ?? '';
    marketRateHighestController.text = data['marketRateHighest']?.toString() ?? '';
    marketRateLowestController.text = data['marketRateLowest']?.toString() ?? '';
    marketRateAverageController.text = data['marketRateAverage']?.toString() ?? '';
    marketSeedRateHighestController.text = data['marketSeedRateHighest']?.toString() ?? '';
    marketSeedRateLowestController.text = data['marketSeedRateLowest']?.toString() ?? '';
    cciPurchaseQtlsController.text = data['cciPurchaseQtls']?.toString() ?? '';
    cciPurchaseBalesController.text = data['cciPurchaseBales']?.toString() ?? '';
    cciKapasMoistureController.text = data['cciKapasMoisture']?.toString() ?? '';
    mspValueDayController.text = data['mspValueDay']?.toString() ?? '';
    mspValueProgController.text = data['mspValueProg']?.toString() ?? '';
    cciRateHighestController.text = data['cciRateHighest']?.toString() ?? '';
    cciRateLowestController.text = data['cciRateLowest']?.toString() ?? '';
    cciRateAverageController.text = data['cciRateAverage']?.toString() ?? '';
    cciSeedRateController.text = data['cciSeedRate']?.toString() ?? '';
    cciOutTurnController.text = data['cciOutTurn']?.toString() ?? '';
    cciShortageController.text = data['cciShortage']?.toString() ?? '';
    cciExpensesController.text = data['cciExpenses']?.toString() ?? '';
    processingCycleController.text = data['processingCycle']?.toString() ?? '';
    cciPadthaController.text = data['cciPadtha']?.toString() ?? '';
    progPurchaseQtlsController.text = data['progPurchaseQtls']?.toString() ?? '';
    progPurchaseBalesController.text = data['progPurchaseBales']?.toString() ?? '';
    progPadthaController.text = data['progPadtha']?.toString() ?? '';
    progAvgRateController.text = data['progAvgRate']?.toString() ?? '';
    balesPressedTodayController.text = data['balesPressedToday']?.toString() ?? '';
    balesPressedProgController.text = data['balesPressedProg']?.toString() ?? '';
    totalBalesShiftedController.text = data['totalBalesShifted']?.toString() ?? '';
    sampleSentController.text = data['sampleSent'] ?? '';
    heapResultController.text = data['heapResult'] ?? '';

    // Load factories - FIXED: proper type casting
    if (data['factories'] is List && (data['factories'] as List).isNotEmpty) {
      purchaseFactories = (data['factories'] as List)
          .map((f) {
        // Cast to Map<String, dynamic> explicitly
        final map = f as Map<String, dynamic>;
        return PurchaseFactoryData.fromJson(map);
      })
          .toList();
    } else {
      purchaseFactories = [
        PurchaseFactoryData(
          factoryName: data['factoryName'] ?? '',
          heapNo: data['heapNo'] ?? 0,
          heapQty: (data['heapQty'] ?? 0).toDouble(),
          seedFarmers: data['seedFarmers'] ?? 0,
          seedRealisable: data['seed_realisable'] ?? 0,
          readySeedSold: data['readySeedSold'] ?? 0,
          readySeedUnsold: data['readySeedUnsold'] ?? 0,
          baseRate: data['baseRate'] ?? 0,
        )
      ];
    }

    if (data['variety'] != null) {
      selectedVariety = data['variety'];
    }
    if (data['date'] != null) {
      selectedDate = DateTime.parse(data['date']);
    }
  }


  @override
  Future<void> onCentreSelected(String centre) async {
    await _fetchPreviousProgressive();
    await autoGenerateReportNo();
  }

  @override
  Future<void> onDateChanged(DateTime date) async {
    await _fetchPreviousProgressive();
  }

  void _recalculateProgApmc() {
    final dayValue = double.tryParse(dayArrivalsApmcController.text) ?? 0;
    final total = previousProgApmc + dayValue;
    progArrivalsApmcController.text = formatNumber(total);
  }

  void _recalculateProgOutside() {
    final dayValue = double.tryParse(dayArrivalsOutsideController.text) ?? 0;
    final total = previousProgOutside + dayValue;
    progArrivalsOutsideController.text = formatNumber(total);
  }

  void _recalculateFarmersProg() {
    final dayValue = double.tryParse(farmersDayController.text) ?? 0;
    final total = previousFarmersProg + dayValue;
    farmersProgressiveController.text = formatNumber(total);
  }

  void _recalculateMspProg() {
    final dayValue = double.tryParse(mspValueDayController.text) ?? 0;
    final total = previousMspProg + dayValue;
    mspValueProgController.text = formatNumber(total);
  }

  void _recalculateBalesProg() {
    final dayValue = double.tryParse(balesPressedTodayController.text) ?? 0;
    final total = previousBalesProg + dayValue;
    balesPressedProgController.text = formatNumber(total);
  }

  Future<void> _fetchPreviousProgressive() async {
    if (widget.isModify) return;
    if (selectedCentre == null || selectedCentre!.isEmpty) {
      setState(() {
        isLoadingPreviousProgressive = false;
        debugMessage = 'No centre selected';
      });
      return;
    }

    setState(() {
      isLoadingPreviousProgressive = true;
      debugMessage = 'Fetching data...';
    });

    final normalizedDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    try {
      final response = await ApiService.getLatestProgressiveArrivals(
        type: 'purchase',
        centre: selectedCentre!,
        beforeDate: normalizedDate,
      );

      if (!mounted) return;

      setState(() {
        isLoadingPreviousProgressive = false;
        if (response.success && response.data != null) {
          previousProgApmc = (response.data!['progArrivalsApmc'] as num?)?.toDouble() ?? 0;
          previousProgOutside = (response.data!['progArrivalsOutside'] as num?)?.toDouble() ?? 0;
          previousFarmersProg = (response.data!['farmersProgressive'] as num?)?.toDouble() ?? 0;
          previousMspProg = (response.data!['mspValueProg'] as num?)?.toDouble() ?? 0;
          previousBalesProg = (response.data!['balesPressedProg'] as num?)?.toDouble() ?? 0;
          debugMessage = '✅ Loaded: APMC=$previousProgApmc, Outside=$previousProgOutside';
        } else {
          previousProgApmc = 0;
          previousProgOutside = 0;
          previousFarmersProg = 0;
          previousMspProg = 0;
          previousBalesProg = 0;
          debugMessage = '⚠️ No previous values found, starting from 0';
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalculateProgApmc();
        _recalculateProgOutside();
        _recalculateFarmersProg();
        _recalculateMspProg();
        _recalculateBalesProg();
      });
    } catch (e) {
      setState(() {
        isLoadingPreviousProgressive = false;
        debugMessage = '❌ Error: $e';
      });
    }
  }

  void _openAddPurchaseFactoryDialog() {
    _showPurchaseFactoryFormDialog(null);
  }

  void _openEditPurchaseFactoryDialog(int index) {
    _showPurchaseFactoryFormDialog(purchaseFactories[index]);
  }

  void _showPurchaseFactoryFormDialog(PurchaseFactoryData? factoryData) {
    final nameController = TextEditingController(text: factoryData?.factoryName ?? '');
    final heapNoController = TextEditingController(text: factoryData?.heapNo.toString() ?? '');
    final heapQtyController = TextEditingController(text: factoryData?.heapQty.toString() ?? '');
    final farmersController = TextEditingController(text: factoryData?.seedFarmers.toString() ?? '');
    final realisableController = TextEditingController(text: factoryData?.seedRealisable.toString() ?? '');
    final soldController = TextEditingController(text: factoryData?.readySeedSold.toString() ?? '');
    final unsoldController = TextEditingController(text: factoryData?.readySeedUnsold.toString() ?? '');
    final baseRateController = TextEditingController(text: factoryData?.baseRate.toString() ?? '');

    final isEditing = factoryData != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Factory' : 'Add Factory'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: factoryFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildTextField(
                    controller: nameController,
                    label: 'Factory Name',
                    hint: 'e.g., A Yesh Patil Cotton Company',
                    icon: Icons.factory,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: buildTextField(
                          controller: heapNoController,
                          label: 'Heap No.',
                          hint: 'e.g., 101',
                          icon: Icons.numbers,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: buildTextField(
                          controller: heapQtyController,
                          label: 'Heap Qty',
                          hint: 'Quintals',
                          icon: Icons.scale,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: buildTextField(
                          controller: farmersController,
                          label: 'Farmers Benefitted',
                          hint: 'e.g., 2',
                          icon: Icons.people,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: buildTextField(
                          controller: realisableController,
                          label: 'Realisable',
                          hint: 'e.g., 70',
                          icon: Icons.attach_money,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: buildTextField(
                          controller: soldController,
                          label: 'Ready Seed Sold',
                          hint: 'e.g., 0',
                          icon: Icons.sell,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: buildTextField(
                          controller: unsoldController,
                          label: 'Ready Seed Unsold',
                          hint: 'e.g., 0',
                          icon: Icons.inbox,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  buildTextField(
                    controller: baseRateController,
                    label: 'Base Rate',
                    hint: 'e.g., 3700',
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (factoryFormKey.currentState!.validate()) {
                final factory = PurchaseFactoryData(
                  factoryName: nameController.text,
                  heapNo: int.tryParse(heapNoController.text) ?? 0,
                  heapQty: double.tryParse(heapQtyController.text) ?? 0,
                  seedFarmers: int.tryParse(farmersController.text) ?? 0,
                  seedRealisable: int.tryParse(realisableController.text) ?? 0,
                  readySeedSold: int.tryParse(soldController.text) ?? 0,
                  readySeedUnsold: int.tryParse(unsoldController.text) ?? 0,
                  baseRate: int.tryParse(baseRateController.text) ?? 0,
                );

                setState(() {
                  if (isEditing) {
                    final index = purchaseFactories.indexOf(factoryData);
                    purchaseFactories[index] = factory;
                  } else {
                    purchaseFactories.add(factory);
                  }
                });

                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isEditing ? const Color(0xFFF59E0B) : const Color(0xFF059669),
            ),
            child: Text(isEditing ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _deletePurchaseFactory(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Factory'),
        content: const Text('Are you sure you want to delete this factory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                purchaseFactories.removeAt(index);
              });
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseFactoryListView() {
    if (purchaseFactories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFF8FAFC),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.factory_outlined, size: 40, color: Color(0xFF94A3B8)),
              SizedBox(height: 8),
              Text(
                'No factories added yet',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              Text(
                'Click "Add Factory" to add one',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
          columns: const [
            DataColumn(label: Text('SNO', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Factory Name', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Heap No.', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Heap Qty', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Farmers', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Realisable', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Seed Sold', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Seed Unsold', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Base Rate', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: purchaseFactories.asMap().entries.map((entry) {
            final index = entry.key;
            final factory = entry.value;
            return DataRow(
              cells: [
                DataCell(Text('${index + 1}')),
                DataCell(Text(factory.factoryName)),
                DataCell(Text(factory.heapNo.toString())),
                DataCell(Text(factory.heapQty.toString())),
                DataCell(Text(factory.seedFarmers.toString())),
                DataCell(Text(factory.seedRealisable.toString())),
                DataCell(Text(factory.readySeedSold.toString())),
                DataCell(Text(factory.readySeedUnsold.toString())),
                DataCell(Text(factory.baseRate.toString())),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _openEditPurchaseFactoryDialog(index),
                        icon: const Icon(Icons.edit, size: 18, color: Color(0xFFF59E0B)),
                        tooltip: 'Edit',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _deletePurchaseFactory(index),
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        tooltip: 'Delete',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  void showCelebration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF059669),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isModify
                  ? 'Purchase Report Updated Successfully!'
                  : 'Purchase Report Created Successfully!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Redirecting to dashboard...',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void submitForm() async {
    if (formKey.currentState!.validate()) {
      setState(() => isSubmitting = true);

      // Explicitly type the map as Map<String, Object>
      final Map<String, Object> data = {
        'reportType': reportType.label,
        'date': selectedDate.toIso8601String(),
        'variety': selectedVariety ?? '',
        'centre': selectedCentre ?? '',
        'reportNo': int.tryParse(reportNoController.text) ?? 0,
        'moisture': moistureController.text,
        'farmersDay': int.tryParse(farmersDayController.text) ?? 0,
        'farmersProgressive': int.tryParse(farmersProgressiveController.text) ?? 0,
        'dayArrivalsApmc': double.tryParse(dayArrivalsApmcController.text) ?? 0,
        'dayArrivalsOutside': double.tryParse(dayArrivalsOutsideController.text) ?? 0,
        'progArrivalsApmc': double.tryParse(progArrivalsApmcController.text) ?? 0,
        'progArrivalsOutside': double.tryParse(progArrivalsOutsideController.text) ?? 0,
        'marketRateHighest': double.tryParse(marketRateHighestController.text) ?? 0,
        'marketRateLowest': double.tryParse(marketRateLowestController.text) ?? 0,
        'marketRateAverage': double.tryParse(marketRateAverageController.text) ?? 0,
        'marketSeedRateHighest': double.tryParse(marketSeedRateHighestController.text) ?? 0,
        'marketSeedRateLowest': double.tryParse(marketSeedRateLowestController.text) ?? 0,
        'cciPurchaseQtls': double.tryParse(cciPurchaseQtlsController.text) ?? 0,
        'cciPurchaseBales': int.tryParse(cciPurchaseBalesController.text) ?? 0,
        'cciKapasMoisture': int.tryParse(cciKapasMoistureController.text) ?? 0,
        'mspValueDay': double.tryParse(mspValueDayController.text) ?? 0,
        'mspValueProg': double.tryParse(mspValueProgController.text) ?? 0,
        'cciRateHighest': double.tryParse(cciRateHighestController.text) ?? 0,
        'cciRateLowest': double.tryParse(cciRateLowestController.text) ?? 0,
        'cciRateAverage': double.tryParse(cciRateAverageController.text) ?? 0,
        'cciSeedRate': int.tryParse(cciSeedRateController.text) ?? 0,
        'cciOutTurn': double.tryParse(cciOutTurnController.text) ?? 0,
        'cciShortage': double.tryParse(cciShortageController.text) ?? 0,
        'cciExpenses': int.tryParse(cciExpensesController.text) ?? 0,
        'processingCycle': int.tryParse(processingCycleController.text) ?? 0,
        'cciPadtha': int.tryParse(cciPadthaController.text) ?? 0,
        'progPurchaseQtls': double.tryParse(progPurchaseQtlsController.text) ?? 0,
        'progPurchaseBales': int.tryParse(progPurchaseBalesController.text) ?? 0,
        'progPadtha': int.tryParse(progPadthaController.text) ?? 0,
        'progAvgRate': int.tryParse(progAvgRateController.text) ?? 0,
        'balesPressedToday': int.tryParse(balesPressedTodayController.text) ?? 0,
        'balesPressedProg': int.tryParse(balesPressedProgController.text) ?? 0,
        'totalBalesShifted': int.tryParse(totalBalesShiftedController.text) ?? 0,
        'sampleSent': sampleSentController.text,
        'heapResult': heapResultController.text,
        'factories': purchaseFactories.map((f) => f.toJson()).toList(),
      };

      if (purchaseFactories.isNotEmpty) {
        data.addAll(purchaseFactories.first.toJson().cast<String, Object>());
      }

      final ApiResponse response;
      if (widget.isModify && docId != null) {
        response = await ApiService.updateEntry(docId!, data);
      } else {
        response = await ApiService.savePurchaseEntry(data);
      }

      if (mounted) {
        setState(() => isSubmitting = false);
        if (response.success) {
          showCelebration();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // ========================================================================
  // BUILD METHOD
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    if (widget.isModify && !entryFound) {
      return _buildLookupDialog();
    }
    return _buildPurchaseFormDialog();
  }

  Widget _buildLookupDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Focus(
        focusNode: dialogFocusNode,
        autofocus: true,
        child: CallbackShortcuts(
          bindings: {
            SingleActivator(LogicalKeyboardKey.escape): () { // Remove const
              Navigator.of(context).pop();
            },
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: lookupFormKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            iconData,
                            color: const Color(0xFF0F172A),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Find Purchase Entry',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        buildCloseButton(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the Centre, Report No. and Date of the entry you '
                          'want to modify.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    buildCentreDropdown(),
                    const SizedBox(height: 12),
                    buildTextField(
                      controller: reportNoController,
                      label: 'Report No.',
                      hint: 'e.g., 1',
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter report number';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Report number must be numeric';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Color(0xFF64748B)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Date: ${formatDate(selectedDate)}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    if (lookupError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lookupError!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSearching ? null : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSearching ? null : findEntry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isSearching
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : const Text(
                              'Find Entry',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseFormDialog() {
    final title = widget.isModify ? 'Modify' : 'Add';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Focus(
        focusNode: dialogFocusNode,
        autofocus: true,
        child: CallbackShortcuts(
          bindings: {
            SingleActivator(LogicalKeyboardKey.escape): () { // Remove const
              Navigator.of(context).pop();
            },
            SingleActivator(LogicalKeyboardKey.arrowUp): () { // Remove const
              scrollController.animateTo(
                scrollController.offset - 50,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            },
            SingleActivator(LogicalKeyboardKey.arrowDown): () { // Remove const
              scrollController.animateTo(
                scrollController.offset + 50,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            },
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            iconData,
                            color: const Color(0xFF0F172A),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$title Purchase Entry',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        buildCloseButton(),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Header
                    if (widget.isModify)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            buildSectionHeader('Header Information'),
                            TextButton.icon(
                              onPressed: isSubmitting ? null : resetLookup,
                              icon: const Icon(Icons.search, size: 16),
                              label: const Text('Change entry'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      buildSectionHeader('Header Information'),

                    buildCentreDropdown(readOnly: widget.isModify),
                    const SizedBox(height: 12),

                    buildTextField(
                      controller: reportNoController,
                      label: 'Report No.',
                      hint: isLoadingReportNo ? 'Generating...' : 'e.g., 1',
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                      readOnly: widget.isModify || isLoadingReportNo,
                      suffixIcon: isLoadingReportNo
                          ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      )
                          : null,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter report number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    InkWell(
                      onTap: widget.isModify ? null : () => selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Color(0xFF64748B)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Date: ${formatDate(selectedDate)}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: selectedVariety,
                      decoration: InputDecoration(
                        labelText: 'Variety',
                        hintText: 'Select variety',
                        prefixIcon: const Icon(Icons.eco),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
                        ),
                      ),
                      items: varieties.map((String variety) {
                        return DropdownMenuItem(
                          value: variety,
                          child: Text(variety),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedVariety = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a variety';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    buildTextField(
                      controller: moistureController,
                      label: 'Moisture Percentage (%)',
                      hint: 'e.g., 8-20%',
                      icon: Icons.water_drop,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter moisture percentage';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Arrivals Section
                    buildSectionHeader('Arrivals'),
                    if (!widget.isModify) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Progressive totals are calculated automatically from '
                              'the last entry for this centre + today\'s values.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                      if (debugMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            debugMessage,
                            style: TextStyle(
                              fontSize: 11,
                              color: debugMessage.contains('✅') ? Colors.green :
                              debugMessage.contains('⚠️') ? Colors.orange :
                              debugMessage.contains('❌') ? Colors.red : Colors.grey,
                            ),
                          ),
                        ),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: buildTextField(
                            controller: dayArrivalsApmcController,
                            label: 'Day APMC',
                            hint: 'Quintals/Bales',
                            icon: Icons.local_shipping,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
                            controller: dayArrivalsOutsideController,
                            label: 'Day Outside',
                            hint: 'Quintals/Bales',
                            icon: Icons.local_shipping_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: buildTextField(
                            controller: progArrivalsApmcController,
                            label: 'Prog APMC',
                            hint: isLoadingPreviousProgressive
                                ? 'Loading previous total...'
                                : 'Quintals/Bales',
                            icon: Icons.trending_up,
                            keyboardType: TextInputType.number,
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
                            controller: progArrivalsOutsideController,
                            label: 'Prog Outside',
                            hint: isLoadingPreviousProgressive
                                ? 'Loading previous total...'
                                : 'Quintals/Bales',
                            icon: Icons.trending_up_outlined,
                            keyboardType: TextInputType.number,
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Market Rates
                    buildSectionHeader('Market Rates (Kapas Rate in Quintals)'),
                    Row(
                      children: [
                        Expanded(
                          child: buildTextField(
                            controller: marketRateHighestController,
                            label: 'Highest',
                            hint: 'e.g., 7785.6',
                            icon: Icons.arrow_upward,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
                            controller: marketRateAverageController,
                            label: 'Average',
                            hint: 'e.g., 7200',
                            icon: Icons.linear_scale,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    buildTextField(
                      controller: marketRateLowestController,
                      label: 'Lowest',
                      hint: 'e.g., 7000',
                      icon: Icons.arrow_downward,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Market Seed Rate',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: buildTextField(
                            controller: marketSeedRateHighestController,
                            label: 'Highest',
                            hint: 'e.g., 3700',
                            icon: Icons.arrow_upward,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
                            controller: marketSeedRateLowestController,
                            label: 'Lowest',
                            hint: 'e.g., 3600',
                            icon: Icons.arrow_downward,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // CCI Purchase
                    buildSectionHeader('CCI Purchase'),
                    Row(
                      children: [
                        Expanded(
                          child: buildTextField(
                            controller: cciPurchaseQtlsController,
                            label: 'Quintals',
                            hint: 'e.g., 109.2',
                            icon: Icons.scale,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
                            controller: cciPurchaseBalesController,
                            label: 'Bales',
                            hint: 'e.g., 22',
                            icon: Icons.inventory,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    buildTextField(
                      controller: cciKapasMoistureController,
                      label: 'Kapas Moisture %',
                      hint: 'e.g., 12',
                      icon: Icons.water_drop,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // MSP Value
                    buildSectionHeader('MSP Value'),
                    if (!widget.isModify) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Progressive MSP is auto-calculated from previous entry + today\'s MSP value',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: buildTextField(
                            controller: mspValueDayController,
                            label: 'Day Wise',
                            hint: 'e.g., 850187.52',
                            icon: Icons.today,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
                            controller: mspValueProgController,
                            label: 'Progressive',
                            hint: isLoadingPreviousProgressive
                                ? 'Loading previous total...'
                                : 'e.g., 850187.52',
                            icon: Icons.trending_up,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Farmers
                    buildSectionHeader('Farmers Benefitted'),
                    if (!widget.isModify) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Progressive Farmers is auto-calculated from previous entry + today\'s farmers',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: buildTextField(
                            controller: farmersDayController,
                            label: 'Day Wise',
                            hint: 'e.g., 2',
                            icon: Icons.people,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
                            controller: farmersProgressiveController,
                            label: 'Progressive',
                            hint: isLoadingPreviousProgressive
                                ? 'Loading previous total...'
                                : 'e.g., 2',
                            icon: Icons.people_outline,
                            keyboardType: TextInputType.number,
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // CCI Rates
                    buildSectionHeader('CCI Rates (Kapas Rate in Quintals)'),
                    Row(
                      children: [
                        Expanded(
                          child: buildTextField(
                            controller: cciRateHighestController,
                            label: 'Highest',
                            hint: 'e.g., 7785.6',
                            icon: Icons.arrow_upward,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
                            controller: cciRateAverageController,
                            label: 'Average',
                            hint: 'e.g., 7785.6',
                            icon: Icons.linear_scale,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    buildTextField(
                      controller: cciRateLowestController,
                      label: 'Lowest',
                      hint: 'e.g., 7785.6',
                      icon: Icons.arrow_downward,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),

                    // CCI Details
                    buildSectionHeader('CCI Details'),
                    Row(
                      children: [
                        Expanded(
                          child: buildTextField(
                            controller: cciSeedRateController,
                            label: 'Seed Rate',
                            hint: 'e.g., 3700',
                            icon: Icons.attach_money,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
                            controller: cciOutTurnController,
                            label: 'Out Turn',
                            hint: 'e.g., 0.33',
                            icon: Icons.percent,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: buildTextField(
                            controller: cciShortageController,
                            label: 'Shortage',
                            hint: 'e.g., 0.035',
                            icon: Icons.warning_amber_rounded,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
                            controller: cciExpensesController,
                            label: 'Expenses',
                            hint: 'e.g., 4050',
                            icon: Icons.money_off,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: buildTextField(
                            controller: processingCycleController,
                            label: 'Processing Cycle',
                            hint: 'e.g., 7 days',
                            icon: Icons.autorenew,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
                            controller: cciPadthaController,
                            label: 'Padtha',
                            hint: 'e.g., 62706',
                            icon: Icons.receipt,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Progressive Purchase
                    buildSectionHeader('Progressive Purchase'),
                    Row(
                      children: [
                        Expanded(
                          child: buildTextField(
                            controller: progPurchaseQtlsController,
                            label: 'Quintals',
                            hint: 'e.g., 109.2',
                            icon: Icons.scale,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
                            controller: progPurchaseBalesController,
                            label: 'Bales',
                            hint: 'e.g., 22',
                            icon: Icons.inventory,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: buildTextField(
                            controller: progPadthaController,
                            label: 'Padtha',
                            hint: 'e.g., 62706',
                            icon: Icons.receipt_long,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
                            controller: progAvgRateController,
                            label: 'Avg Rate',
                            hint: 'e.g., 62706',
                            icon: Icons.calculate,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Bales Pressed
                    buildSectionHeader('Bales Pressed'),
                    if (!widget.isModify) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Progressive Bales is auto-calculated from previous entry + today\'s bales',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: buildTextField(
                            controller: balesPressedTodayController,
                            label: 'Today',
                            hint: 'e.g., 0',
                            icon: Icons.today,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
                            controller: balesPressedProgController,
                            label: 'Progressive',
                            hint: isLoadingPreviousProgressive
                                ? 'Loading previous total...'
                                : 'e.g., 0',
                            icon: Icons.trending_up,
                            keyboardType: TextInputType.number,
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    buildTextField(
                      controller: totalBalesShiftedController,
                      label: 'Total Bales Shifted to Godown',
                      hint: 'e.g., 0',
                      icon: Icons.warehouse,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Other Details
                    buildSectionHeader('Other Details'),
                    Row(
                      children: [
                        Expanded(
                          child: buildTextField(
                            controller: sampleSentController,
                            label: 'Sample Sent to B.O',
                            hint: 'e.g., - or Yes',
                            icon: Icons.send,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
                            controller: heapResultController,
                            label: 'Heap Result Sent to B.O',
                            hint: 'e.g., - or Yes',
                            icon: Icons.check_circle_outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Factory Details
                    buildSectionHeaderWithAction(
                      'Factory Details',
                      actionLabel: 'Add Factory',
                      onAction: _openAddPurchaseFactoryDialog,
                    ),
                    const SizedBox(height: 12),
                    _buildPurchaseFactoryListView(),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : Text(
                              widget.isModify ? 'Update' : 'Submit',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}