import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../enums/report_type.dart';
import '../services/apiservice.dart';

// Simple factory data model for table view
class FactoryData {
  String factoryName;
  int heapNo;
  double heapQty;
  int seedFarmers;
  int seedRealisable;
  int readySeedSold;
  int readySeedUnsold;
  int baseRate;

  FactoryData({
    required this.factoryName,
    required this.heapNo,
    required this.heapQty,
    required this.seedFarmers,
    required this.seedRealisable,
    required this.readySeedSold,
    required this.readySeedUnsold,
    required this.baseRate,
  });

  Map<String, dynamic> toJson() => {
    'factoryName': factoryName,
    'heapNo': heapNo,
    'heapQty': heapQty,
    'seedFarmers': seedFarmers,
    'seed_realisable': seedRealisable,
    'readySeedSold': readySeedSold,
    'readySeedUnsold': readySeedUnsold,
    'baseRate': baseRate,
  };

  factory FactoryData.fromJson(Map<String, dynamic> json) => FactoryData(
    factoryName: json['factoryName'] ?? '',
    heapNo: json['heapNo'] ?? 0,
    heapQty: (json['heapQty'] ?? 0).toDouble(),
    seedFarmers: json['seedFarmers'] ?? 0,
    seedRealisable: json['seed_realisable'] ?? 0,
    readySeedSold: json['readySeedSold'] ?? 0,
    readySeedUnsold: json['readySeedUnsold'] ?? 0,
    baseRate: json['baseRate'] ?? 0,
  );
}

class CreateEntryDialog extends StatefulWidget {
  final ReportType type;
  final bool isModify;
  final Map<String, dynamic>? existingData;

  const CreateEntryDialog({
    super.key,
    required this.type,
    this.isModify = false,
    this.existingData,
  });

  @override
  State<CreateEntryDialog> createState() => _CreateEntryDialogState();
}

class _CreateEntryDialogState extends State<CreateEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _lookupFormKey = GlobalKey<FormState>();
  final _factoryFormKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _dialogFocusNode = FocusNode();
  bool _isSubmitting = false;

  // ============ MODIFY: FIND-THEN-EDIT FLOW ============
  bool _entryFound = false;
  bool _isSearching = false;
  String? _docId;
  String? _lookupError;

  // ============ HEADER FIELDS ============
  String? _selectedCentre;
  final _reportNoController = TextEditingController();
  final _moistureController = TextEditingController();

  // ============ FARMERS BENEFITTED ============
  final _farmersDayController = TextEditingController();
  final _farmersProgressiveController = TextEditingController();
  double _previousFarmersProg = 0;

  // ============ ARRIVALS ============
  final _dayArrivalsApmcController = TextEditingController();
  final _dayArrivalsOutsideController = TextEditingController();
  final _progArrivalsApmcController = TextEditingController();
  final _progArrivalsOutsideController = TextEditingController();
  double _previousProgApmc = 0;
  double _previousProgOutside = 0;

  // ============ MARKET RATES ============
  final _marketRateHighestController = TextEditingController();
  final _marketRateLowestController = TextEditingController();
  final _marketRateAverageController = TextEditingController();
  final _marketSeedRateHighestController = TextEditingController();
  final _marketSeedRateLowestController = TextEditingController();

  // ============ CCI PURCHASE ============
  final _cciPurchaseQtlsController = TextEditingController();
  final _cciPurchaseBalesController = TextEditingController();
  final _cciKapasMoistureController = TextEditingController();

  // ============ MSP VALUE ============
  final _mspValueDayController = TextEditingController();
  final _mspValueProgController = TextEditingController();
  double _previousMspProg = 0;

  // ============ CCI RATES ============
  final _cciRateHighestController = TextEditingController();
  final _cciRateLowestController = TextEditingController();
  final _cciRateAverageController = TextEditingController();

  // ============ CCI DETAILS ============
  final _cciSeedRateController = TextEditingController();
  final _cciOutTurnController = TextEditingController();
  final _cciShortageController = TextEditingController();
  final _cciExpensesController = TextEditingController();
  final _processingCycleController = TextEditingController();
  final _cciPadthaController = TextEditingController();

  // ============ PROGRESSIVE ============
  final _progPurchaseQtlsController = TextEditingController();
  final _progPurchaseBalesController = TextEditingController();
  final _progPadthaController = TextEditingController();
  final _progAvgRateController = TextEditingController();

  // ============ BALES PRESSED ============
  final _balesPressedTodayController = TextEditingController();
  final _balesPressedProgController = TextEditingController();
  double _previousBalesProg = 0;

  final _totalBalesShiftedController = TextEditingController();

  // ============ OTHER ============
  final _sampleSentController = TextEditingController();
  final _heapResultController = TextEditingController();

  // ============ FACTORY DETAILS ============
  List<FactoryData> _factories = [];

  DateTime _selectedDate = DateTime.now();
  String? _selectedVariety;

  final List<String> _varieties = [
    'BB MOD',
    'H-4',
    'DCH-32',
    'Suvin',
    'J-34',
    'LRA',
  ];

  final List<String> _centres = [
    'Devadurga',
    'Raichur',
    'Sindhanur',
    'Lingasugur',
    'Manvi',
    'Sirwar',
  ];

  bool _isLoadingPreviousProgressive = false;
  String _debugMessage = '';

  @override
  void initState() {
    super.initState();

    if (widget.isModify && widget.existingData != null) {
      _loadExistingData(widget.existingData!);
      _docId = widget.existingData!['id']?.toString();
      _entryFound = true;
    } else if (!widget.isModify) {
      _entryFound = true;
      _factories = [];

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadDefaultCentre();

        if (_selectedCentre != null && _selectedCentre!.isNotEmpty) {
          await _fetchPreviousProgressive();
        } else {
          setState(() {
            _isLoadingPreviousProgressive = false;
          });
        }
      });
    }

    // Auto-accumulation listeners for day fields
    if (!widget.isModify) {
      _dayArrivalsApmcController.addListener(_recalculateProgApmc);
      _dayArrivalsOutsideController.addListener(_recalculateProgOutside);
      _farmersDayController.addListener(_recalculateFarmersProg);
      _mspValueDayController.addListener(_recalculateMspProg);
      _balesPressedTodayController.addListener(_recalculateBalesProg);
    }

    // Request focus for keyboard events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_dialogFocusNode);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _dialogFocusNode.dispose();
    _reportNoController.dispose();
    _moistureController.dispose();
    _farmersDayController.dispose();
    _farmersProgressiveController.dispose();
    _dayArrivalsApmcController.dispose();
    _dayArrivalsOutsideController.dispose();
    _progArrivalsApmcController.dispose();
    _progArrivalsOutsideController.dispose();
    _marketRateHighestController.dispose();
    _marketRateLowestController.dispose();
    _marketRateAverageController.dispose();
    _marketSeedRateHighestController.dispose();
    _marketSeedRateLowestController.dispose();
    _cciPurchaseQtlsController.dispose();
    _cciPurchaseBalesController.dispose();
    _cciKapasMoistureController.dispose();
    _mspValueDayController.dispose();
    _mspValueProgController.dispose();
    _cciRateHighestController.dispose();
    _cciRateLowestController.dispose();
    _cciRateAverageController.dispose();
    _cciSeedRateController.dispose();
    _cciOutTurnController.dispose();
    _cciShortageController.dispose();
    _cciExpensesController.dispose();
    _processingCycleController.dispose();
    _cciPadthaController.dispose();
    _progPurchaseQtlsController.dispose();
    _progPurchaseBalesController.dispose();
    _progPadthaController.dispose();
    _progAvgRateController.dispose();
    _balesPressedTodayController.dispose();
    _balesPressedProgController.dispose();
    _totalBalesShiftedController.dispose();
    _sampleSentController.dispose();
    _heapResultController.dispose();
    super.dispose();
  }

  void _loadExistingData(Map<String, dynamic> data) {
    final centre = data['centre'] as String?;
    _selectedCentre = (centre != null && centre.isNotEmpty) ? centre : null;
    _reportNoController.text = data['reportNo']?.toString() ?? '';
    _moistureController.text = data['moisture'] ?? '';
    _farmersDayController.text = data['farmersDay']?.toString() ?? '';
    _farmersProgressiveController.text = data['farmersProgressive']?.toString() ?? '';
    _dayArrivalsApmcController.text = data['dayArrivalsApmc']?.toString() ?? '';
    _dayArrivalsOutsideController.text = data['dayArrivalsOutside']?.toString() ?? '';
    _progArrivalsApmcController.text = data['progArrivalsApmc']?.toString() ?? '';
    _progArrivalsOutsideController.text = data['progArrivalsOutside']?.toString() ?? '';
    _marketRateHighestController.text = data['marketRateHighest']?.toString() ?? '';
    _marketRateLowestController.text = data['marketRateLowest']?.toString() ?? '';
    _marketRateAverageController.text = data['marketRateAverage']?.toString() ?? '';
    _marketSeedRateHighestController.text = data['marketSeedRateHighest']?.toString() ?? '';
    _marketSeedRateLowestController.text = data['marketSeedRateLowest']?.toString() ?? '';
    _cciPurchaseQtlsController.text = data['cciPurchaseQtls']?.toString() ?? '';
    _cciPurchaseBalesController.text = data['cciPurchaseBales']?.toString() ?? '';
    _cciKapasMoistureController.text = data['cciKapasMoisture']?.toString() ?? '';
    _mspValueDayController.text = data['mspValueDay']?.toString() ?? '';
    _mspValueProgController.text = data['mspValueProg']?.toString() ?? '';
    _cciRateHighestController.text = data['cciRateHighest']?.toString() ?? '';
    _cciRateLowestController.text = data['cciRateLowest']?.toString() ?? '';
    _cciRateAverageController.text = data['cciRateAverage']?.toString() ?? '';
    _cciSeedRateController.text = data['cciSeedRate']?.toString() ?? '';
    _cciOutTurnController.text = data['cciOutTurn']?.toString() ?? '';
    _cciShortageController.text = data['cciShortage']?.toString() ?? '';
    _cciExpensesController.text = data['cciExpenses']?.toString() ?? '';
    _processingCycleController.text = data['processingCycle']?.toString() ?? '';
    _cciPadthaController.text = data['cciPadtha']?.toString() ?? '';
    _progPurchaseQtlsController.text = data['progPurchaseQtls']?.toString() ?? '';
    _progPurchaseBalesController.text = data['progPurchaseBales']?.toString() ?? '';
    _progPadthaController.text = data['progPadtha']?.toString() ?? '';
    _progAvgRateController.text = data['progAvgRate']?.toString() ?? '';
    _balesPressedTodayController.text = data['balesPressedToday']?.toString() ?? '';
    _balesPressedProgController.text = data['balesPressedProg']?.toString() ?? '';
    _totalBalesShiftedController.text = data['totalBalesShifted']?.toString() ?? '';
    _sampleSentController.text = data['sampleSent'] ?? '';
    _heapResultController.text = data['heapResult'] ?? '';

    // Load factories
    if (data['factories'] is List && (data['factories'] as List).isNotEmpty) {
      _factories = (data['factories'] as List)
          .map((f) => FactoryData.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList();
    } else {
      _factories = [
        FactoryData(
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
      _selectedVariety = data['variety'];
    }
    if (data['date'] != null) {
      _selectedDate = DateTime.parse(data['date']);
    }
  }

  // ---------------------------------------------------------------------
  // Progressive auto-accumulation methods
  // ---------------------------------------------------------------------

  static const _prefKeyLastCentre = 'last_used_centre';

  Future<void> _loadDefaultCentre() async {
    if (_selectedCentre != null) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKeyLastCentre);
    if (!mounted) return;
    if (saved != null && _centres.contains(saved)) {
      setState(() {
        _selectedCentre = saved;
      });
    }
  }

  Future<void> _rememberCentre(String centre) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyLastCentre, centre);
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  void _recalculateProgApmc() {
    final dayValue = double.tryParse(_dayArrivalsApmcController.text) ?? 0;
    final total = _previousProgApmc + dayValue;
    _progArrivalsApmcController.text = _formatNumber(total);
    print('📊 Recalculated Prog APMC: $_previousProgApmc + $dayValue = $total');
  }

  void _recalculateProgOutside() {
    final dayValue = double.tryParse(_dayArrivalsOutsideController.text) ?? 0;
    final total = _previousProgOutside + dayValue;
    _progArrivalsOutsideController.text = _formatNumber(total);
    print('📊 Recalculated Prog Outside: $_previousProgOutside + $dayValue = $total');
  }

  void _recalculateFarmersProg() {
    final dayValue = double.tryParse(_farmersDayController.text) ?? 0;
    final total = _previousFarmersProg + dayValue;
    _farmersProgressiveController.text = _formatNumber(total);
  }

  void _recalculateMspProg() {
    final dayValue = double.tryParse(_mspValueDayController.text) ?? 0;
    final total = _previousMspProg + dayValue;
    _mspValueProgController.text = _formatNumber(total);
  }

  void _recalculateBalesProg() {
    final dayValue = double.tryParse(_balesPressedTodayController.text) ?? 0;
    final total = _previousBalesProg + dayValue;
    _balesPressedProgController.text = _formatNumber(total);
  }

  Future<void> _fetchPreviousProgressive() async {
    if (widget.isModify) return;
    if (_selectedCentre == null || _selectedCentre!.isEmpty) {
      setState(() {
        _isLoadingPreviousProgressive = false;
        _debugMessage = 'No centre selected';
      });
      return;
    }

    print('🔍 Fetching progressive values for centre: $_selectedCentre');
    setState(() {
      _isLoadingPreviousProgressive = true;
      _debugMessage = 'Fetching data...';
    });

    final isPurchase = widget.type == ReportType.dailyPurchase;
    final normalizedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    print('📅 Looking for entries before: $normalizedDate');

    try {
      final response = await ApiService.getLatestProgressiveArrivals(
        type: isPurchase ? 'purchase' : 'seed',
        centre: _selectedCentre!,
        beforeDate: normalizedDate,
      );

      print('📥 Response success: ${response.success}');
      print('📥 Response message: ${response.message}');
      print('📥 Response data: ${response.data}');

      if (!mounted) return;

      setState(() {
        _isLoadingPreviousProgressive = false;

        if (response.success && response.data != null) {
          _previousProgApmc = (response.data!['progArrivalsApmc'] as num?)?.toDouble() ?? 0;
          _previousProgOutside = (response.data!['progArrivalsOutside'] as num?)?.toDouble() ?? 0;
          _previousFarmersProg = (response.data!['farmersProgressive'] as num?)?.toDouble() ?? 0;
          _previousMspProg = (response.data!['mspValueProg'] as num?)?.toDouble() ?? 0;
          _previousBalesProg = (response.data!['balesPressedProg'] as num?)?.toDouble() ?? 0;

          _debugMessage = '✅ Loaded: APMC=$_previousProgApmc, Outside=$_previousProgOutside';
          print('✅ Values loaded: progApmc=$_previousProgApmc, progOutside=$_previousProgOutside');
        } else {
          _previousProgApmc = 0;
          _previousProgOutside = 0;
          _previousFarmersProg = 0;
          _previousMspProg = 0;
          _previousBalesProg = 0;
          _debugMessage = '⚠️ No previous values found, starting from 0';
          print('⚠️ No previous values found, starting from 0');
        }
      });

      // Recalculate all progressive fields after state update
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalculateProgApmc();
        _recalculateProgOutside();
        _recalculateFarmersProg();
        _recalculateMspProg();
        _recalculateBalesProg();
      });
    } catch (e) {
      print('❌ Error fetching: $e');
      setState(() {
        _isLoadingPreviousProgressive = false;
        _debugMessage = '❌ Error: $e';
      });
    }
  }

  // ---------------------------------------------------------------------
  // Date formatting
  // ---------------------------------------------------------------------

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  // ---------------------------------------------------------------------
  // Keyboard Navigation
  // ---------------------------------------------------------------------

  void _scrollUp() {
    _scrollController.animateTo(
      _scrollController.offset - 50,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  void _scrollDown() {
    _scrollController.animateTo(
      _scrollController.offset + 50,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  // ---------------------------------------------------------------------
  // Factory management methods
  // ---------------------------------------------------------------------

  void _openAddFactoryDialog() {
    _showFactoryFormDialog(null);
  }

  void _openEditFactoryDialog(int index) {
    _showFactoryFormDialog(_factories[index]);
  }

  void _showFactoryFormDialog(FactoryData? factoryData) {
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
            key: _factoryFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(
                    controller: nameController,
                    label: 'Factory Name',
                    hint: 'e.g., A Yesh Patil Cotton Company',
                    icon: Icons.factory,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: heapNoController,
                          label: 'Heap No.',
                          hint: 'e.g., 101',
                          icon: Icons.numbers,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
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
                        child: _buildTextField(
                          controller: farmersController,
                          label: 'Farmers Benefitted',
                          hint: 'e.g., 2',
                          icon: Icons.people,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
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
                        child: _buildTextField(
                          controller: soldController,
                          label: 'Ready Seed Sold',
                          hint: 'e.g., 0',
                          icon: Icons.sell,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
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
                  _buildTextField(
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
              if (_factoryFormKey.currentState!.validate()) {
                final factory = FactoryData(
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
                    final index = _factories.indexOf(factoryData);
                    _factories[index] = factory;
                  } else {
                    _factories.add(factory);
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

  void _deleteFactory(int index) {
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
                _factories.removeAt(index);
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

  // ---------------------------------------------------------------------
  // Lookup / modify flow
  // ---------------------------------------------------------------------

  Future<void> _findEntry() async {
    if (!_lookupFormKey.currentState!.validate()) return;
    if (_selectedCentre == null) return;

    final reportNo = int.tryParse(_reportNoController.text);
    if (reportNo == null) return;

    setState(() {
      _isSearching = true;
      _lookupError = null;
    });

    final isPurchase = widget.type == ReportType.dailyPurchase;
    final normalizedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    final response = await ApiService.findEntry(
      type: isPurchase ? 'purchase' : 'seed',
      centre: _selectedCentre!,
      reportNo: reportNo,
      date: normalizedDate,
    );

    if (!mounted) return;

    if (response.success && response.data != null) {
      final entry = Map<String, dynamic>.from(
        response.data!['entry'] as Map,
      );
      setState(() {
        _isSearching = false;
        _lookupError = null;
        _docId = entry['id']?.toString();
        _entryFound = true;
      });
      _loadExistingData(entry);
    } else {
      setState(() {
        _isSearching = false;
        _lookupError = response.message;
      });
    }
  }

  void _resetLookup() {
    setState(() {
      _entryFound = false;
      _docId = null;
      _lookupError = null;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _fetchPreviousProgressive();
    }
  }

  void _showCelebration() {
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
                  ? 'Report Updated Successfully!'
                  : 'Report Created Successfully!',
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

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      final isPurchase = widget.type == ReportType.dailyPurchase;
      final Map<String, dynamic> data = {
        'reportType': widget.type.label,
        'date': _selectedDate.toIso8601String(),
        'variety': _selectedVariety ?? '',
        'centre': _selectedCentre ?? '',
        'reportNo': int.tryParse(_reportNoController.text) ?? 0,
        'moisture': _moistureController.text,
        'farmersDay': int.tryParse(_farmersDayController.text) ?? 0,
        'farmersProgressive': int.tryParse(_farmersProgressiveController.text) ?? 0,
        'dayArrivalsApmc': double.tryParse(_dayArrivalsApmcController.text) ?? 0,
        'dayArrivalsOutside': double.tryParse(_dayArrivalsOutsideController.text) ?? 0,
        'progArrivalsApmc': double.tryParse(_progArrivalsApmcController.text) ?? 0,
        'progArrivalsOutside': double.tryParse(_progArrivalsOutsideController.text) ?? 0,
        'marketRateHighest': double.tryParse(_marketRateHighestController.text) ?? 0,
        'marketRateLowest': double.tryParse(_marketRateLowestController.text) ?? 0,
        'marketRateAverage': double.tryParse(_marketRateAverageController.text) ?? 0,
        'marketSeedRateHighest': double.tryParse(_marketSeedRateHighestController.text) ?? 0,
        'marketSeedRateLowest': double.tryParse(_marketSeedRateLowestController.text) ?? 0,
        'cciPurchaseQtls': double.tryParse(_cciPurchaseQtlsController.text) ?? 0,
        'cciPurchaseBales': int.tryParse(_cciPurchaseBalesController.text) ?? 0,
        'cciKapasMoisture': int.tryParse(_cciKapasMoistureController.text) ?? 0,
        'mspValueDay': double.tryParse(_mspValueDayController.text) ?? 0,
        'mspValueProg': double.tryParse(_mspValueProgController.text) ?? 0,
        'cciRateHighest': double.tryParse(_cciRateHighestController.text) ?? 0,
        'cciRateLowest': double.tryParse(_cciRateLowestController.text) ?? 0,
        'cciRateAverage': double.tryParse(_cciRateAverageController.text) ?? 0,
        'cciSeedRate': int.tryParse(_cciSeedRateController.text) ?? 0,
        'cciOutTurn': double.tryParse(_cciOutTurnController.text) ?? 0,
        'cciShortage': double.tryParse(_cciShortageController.text) ?? 0,
        'cciExpenses': int.tryParse(_cciExpensesController.text) ?? 0,
        'processingCycle': int.tryParse(_processingCycleController.text) ?? 0,
        'cciPadtha': int.tryParse(_cciPadthaController.text) ?? 0,
        'progPurchaseQtls': double.tryParse(_progPurchaseQtlsController.text) ?? 0,
        'progPurchaseBales': int.tryParse(_progPurchaseBalesController.text) ?? 0,
        'progPadtha': int.tryParse(_progPadthaController.text) ?? 0,
        'progAvgRate': int.tryParse(_progAvgRateController.text) ?? 0,
        'balesPressedToday': int.tryParse(_balesPressedTodayController.text) ?? 0,
        'balesPressedProg': int.tryParse(_balesPressedProgController.text) ?? 0,
        'totalBalesShifted': int.tryParse(_totalBalesShiftedController.text) ?? 0,
        'sampleSent': _sampleSentController.text,
        'heapResult': _heapResultController.text,
        'factories': _factories.map((f) => f.toJson()).toList(),
      };

      if (_factories.isNotEmpty) {
        data.addAll(_factories.first.toJson());
      }

      final ApiResponse response;
      if (widget.isModify && _docId != null) {
        response = await ApiService.updateEntry(_docId!, data);
      } else {
        response = isPurchase
            ? await ApiService.savePurchaseEntry(data)
            : await ApiService.saveSeedEntry(data);
      }

      if (mounted) {
        setState(() => _isSubmitting = false);

        if (response.success) {
          _showCelebration();
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
  // BUILD METHODS
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    final isPurchase = widget.type == ReportType.dailyPurchase;

    if (widget.isModify && !_entryFound) {
      return _buildLookupDialog(context, isPurchase);
    }

    return _buildFullFormDialog(context, isPurchase);
  }

  Widget _buildCloseButton() {
    return IconButton(
      onPressed: () => Navigator.of(context).pop(),
      icon: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(4),
        child: const Icon(
          Icons.close,
          size: 20,
          color: Color(0xFF64748B),
        ),
      ),
      tooltip: 'Close',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildLookupDialog(BuildContext context, bool isPurchase) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Focus(
        focusNode: _dialogFocusNode,
        autofocus: true,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              Navigator.of(context).pop();
            },
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _lookupFormKey,
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
                            color: isPurchase ? const Color(0xFFE0F2FE) : const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isPurchase ? Icons.shopping_basket_rounded : Icons.eco_rounded,
                            color: const Color(0xFF0F172A),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Find ${isPurchase ? 'Purchase' : 'Seed'} Entry',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        _buildCloseButton(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the Centre, Report No. and Date of the entry you '
                          'want to modify. The rest of the details will appear once '
                          'we find a match.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    _buildCentreDropdown(),
                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _reportNoController,
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
                      onTap: () => _selectDate(context),
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
                                'Date: ${_formatDate(_selectedDate)}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),

                    if (_lookupError != null) ...[
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
                                _lookupError!,
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
                            onPressed: _isSearching ? null : () => Navigator.of(context).pop(),
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
                            onPressed: _isSearching ? null : _findEntry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSearching
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

  Widget _buildFullFormDialog(BuildContext context, bool isPurchase) {
    final title = widget.isModify ? 'Modify' : 'Add';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Focus(
        focusNode: _dialogFocusNode,
        autofocus: true,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              Navigator.of(context).pop();
            },
            const SingleActivator(LogicalKeyboardKey.arrowUp): () {
              _scrollUp();
            },
            const SingleActivator(LogicalKeyboardKey.arrowDown): () {
              _scrollDown();
            },
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isPurchase ? const Color(0xFFE0F2FE) : const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isPurchase ? Icons.shopping_basket_rounded : Icons.eco_rounded,
                            color: const Color(0xFF0F172A),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$title ${isPurchase ? 'Purchase' : 'Seed'} Entry',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        _buildCloseButton(),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (widget.isModify)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionHeader('Header Information'),
                            TextButton.icon(
                              onPressed: _isSubmitting ? null : _resetLookup,
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
                      _buildSectionHeader('Header Information'),

                    _buildCentreDropdown(readOnly: widget.isModify),
                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: _reportNoController,
                      label: 'Report No.',
                      hint: 'e.g., 1',
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                      readOnly: widget.isModify,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter report number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    InkWell(
                      onTap: widget.isModify ? null : () => _selectDate(context),
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
                                'Date: ${_formatDate(_selectedDate)}',
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
                      value: _selectedVariety,
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
                      items: _varieties.map((String variety) {
                        return DropdownMenuItem(
                          value: variety,
                          child: Text(variety),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedVariety = value;
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

                    _buildTextField(
                      controller: _moistureController,
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

                    _buildSectionHeader('Arrivals'),
                    if (!widget.isModify) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Progressive totals are calculated automatically from '
                              'the last entry for this centre + today\'s values.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                      if (_debugMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            _debugMessage,
                            style: TextStyle(
                              fontSize: 11,
                              color: _debugMessage.contains('✅') ? Colors.green :
                              _debugMessage.contains('⚠️') ? Colors.orange :
                              _debugMessage.contains('❌') ? Colors.red : Colors.grey,
                            ),
                          ),
                        ),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _dayArrivalsApmcController,
                            label: 'Day APMC',
                            hint: 'Quintals/Bales',
                            icon: Icons.local_shipping,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _dayArrivalsOutsideController,
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
                          child: _buildTextField(
                            controller: _progArrivalsApmcController,
                            label: 'Prog APMC',
                            hint: _isLoadingPreviousProgressive
                                ? 'Loading previous total...'
                                : 'Quintals/Bales',
                            icon: Icons.trending_up,
                            keyboardType: TextInputType.number,
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _progArrivalsOutsideController,
                            label: 'Prog Outside',
                            hint: _isLoadingPreviousProgressive
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

                    _buildSectionHeader('Market Rates (Kapas Rate in Quintals)'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _marketRateHighestController,
                            label: 'Highest',
                            hint: 'e.g., 7785.6',
                            icon: Icons.arrow_upward,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _marketRateAverageController,
                            label: 'Average',
                            hint: 'e.g., 7200',
                            icon: Icons.linear_scale,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _marketRateLowestController,
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
                          child: _buildTextField(
                            controller: _marketSeedRateHighestController,
                            label: 'Highest',
                            hint: 'e.g., 3700',
                            icon: Icons.arrow_upward,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _marketSeedRateLowestController,
                            label: 'Lowest',
                            hint: 'e.g., 3600',
                            icon: Icons.arrow_downward,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildSectionHeader('CCI Purchase'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _cciPurchaseQtlsController,
                            label: 'Quintals',
                            hint: 'e.g., 109.2',
                            icon: Icons.scale,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _cciPurchaseBalesController,
                            label: 'Bales',
                            hint: 'e.g., 22',
                            icon: Icons.inventory,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _cciKapasMoistureController,
                      label: 'Kapas Moisture %',
                      hint: 'e.g., 12',
                      icon: Icons.water_drop,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    _buildSectionHeader('MSP Value'),
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
                          child: _buildTextField(
                            controller: _mspValueDayController,
                            label: 'Day Wise',
                            hint: 'e.g., 850187.52',
                            icon: Icons.today,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _mspValueProgController,
                            label: 'Progressive',
                            hint: _isLoadingPreviousProgressive
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

                    _buildSectionHeader('Farmers Benefitted'),
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
                          child: _buildTextField(
                            controller: _farmersDayController,
                            label: 'Day Wise',
                            hint: 'e.g., 2',
                            icon: Icons.people,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _farmersProgressiveController,
                            label: 'Progressive',
                            hint: _isLoadingPreviousProgressive
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

                    _buildSectionHeader('CCI Rates (Kapas Rate in Quintals)'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _cciRateHighestController,
                            label: 'Highest',
                            hint: 'e.g., 7785.6',
                            icon: Icons.arrow_upward,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _cciRateAverageController,
                            label: 'Average',
                            hint: 'e.g., 7785.6',
                            icon: Icons.linear_scale,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _cciRateLowestController,
                      label: 'Lowest',
                      hint: 'e.g., 7785.6',
                      icon: Icons.arrow_downward,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),

                    _buildSectionHeader('CCI Details'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _cciSeedRateController,
                            label: 'Seed Rate',
                            hint: 'e.g., 3700',
                            icon: Icons.attach_money,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _cciOutTurnController,
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
                          child: _buildTextField(
                            controller: _cciShortageController,
                            label: 'Shortage',
                            hint: 'e.g., 0.035',
                            icon: Icons.warning_amber_rounded,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _cciExpensesController,
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
                          child: _buildTextField(
                            controller: _processingCycleController,
                            label: 'Processing Cycle',
                            hint: 'e.g., 7 days',
                            icon: Icons.autorenew,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _cciPadthaController,
                            label: 'Padtha',
                            hint: 'e.g., 62706',
                            icon: Icons.receipt,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildSectionHeader('Progressive Purchase'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _progPurchaseQtlsController,
                            label: 'Quintals',
                            hint: 'e.g., 109.2',
                            icon: Icons.scale,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _progPurchaseBalesController,
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
                          child: _buildTextField(
                            controller: _progPadthaController,
                            label: 'Padtha',
                            hint: 'e.g., 62706',
                            icon: Icons.receipt_long,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _progAvgRateController,
                            label: 'Avg Rate',
                            hint: 'e.g., 62706',
                            icon: Icons.calculate,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildSectionHeader('Bales Pressed'),
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
                          child: _buildTextField(
                            controller: _balesPressedTodayController,
                            label: 'Today',
                            hint: 'e.g., 0',
                            icon: Icons.today,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _balesPressedProgController,
                            label: 'Progressive',
                            hint: _isLoadingPreviousProgressive
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

                    _buildTextField(
                      controller: _totalBalesShiftedController,
                      label: 'Total Bales Shifted to Godown',
                      hint: 'e.g., 0',
                      icon: Icons.warehouse,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    _buildSectionHeader('Other Details'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _sampleSentController,
                            label: 'Sample Sent to B.O',
                            hint: 'e.g., - or Yes',
                            icon: Icons.send,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _heapResultController,
                            label: 'Heap Result Sent to B.O',
                            hint: 'e.g., - or Yes',
                            icon: Icons.check_circle_outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildSectionHeaderWithAction(
                      'Factory Details',
                      actionLabel: 'Add Factory',
                      onAction: _openAddFactoryDialog,
                    ),
                    const SizedBox(height: 12),
                    _buildFactoryListView(),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
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
                            onPressed: _isSubmitting ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSubmitting
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

  // ========================================================================
  // REUSABLE WIDGETS
  // ========================================================================

  Widget _buildFactoryListView() {
    if (_factories.isEmpty) {
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
          rows: _factories.asMap().entries.map((entry) {
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
                        onPressed: () => _openEditFactoryDialog(index),
                        icon: const Icon(Icons.edit, size: 18, color: Color(0xFFF59E0B)),
                        tooltip: 'Edit',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _deleteFactory(index),
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

  Widget _buildCentreDropdown({bool readOnly = false}) {
    return DropdownButtonFormField<String>(
      value: _selectedCentre,
      decoration: InputDecoration(
        labelText: 'Centre',
        hintText: 'Select centre',
        prefixIcon: const Icon(Icons.location_city),
        filled: readOnly,
        fillColor: readOnly ? const Color(0xFFF1F5F9) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
        ),
      ),
      items: _centres.map((String centre) {
        return DropdownMenuItem(
          value: centre,
          child: Text(centre),
        );
      }).toList(),
      onChanged: readOnly
          ? null
          : (value) {
        setState(() {
          _selectedCentre = value;
          _previousProgApmc = 0;
          _previousProgOutside = 0;
          _previousFarmersProg = 0;
          _previousMspProg = 0;
          _previousBalesProg = 0;
          _debugMessage = '';

          // Clear progressive fields when changing centre
          _progArrivalsApmcController.text = '';
          _progArrivalsOutsideController.text = '';
          _farmersProgressiveController.text = '';
          _mspValueProgController.text = '';
          _balesPressedProgController.text = '';
        });
        if (value != null) {
          _rememberCentre(value);
          _fetchPreviousProgressive();
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a centre';
        }
        return null;
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeaderWithAction(
      String title, {
        required String actionLabel,
        required VoidCallback onAction,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFF0F172A)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              actionLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      style: readOnly ? const TextStyle(color: Color(0xFF64748B)) : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: readOnly,
        fillColor: readOnly ? const Color(0xFFF1F5F9) : null,
        prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}