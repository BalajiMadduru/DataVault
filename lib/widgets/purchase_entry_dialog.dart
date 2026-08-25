import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../enums/report_type.dart';
import '../models/report_modals.dart';
import '../models/proforma_modal.dart';
import '../screens/find_entry_dialog.dart';
import '../screens/proforma_view_screen.dart';
import '../services/apiservice.dart';
import '../widgets/common_form_widgets.dart';

class PurchaseEntryDialog extends StatefulWidget {
  final bool isModify;
  final Map<String, dynamic>? existingData;

  const PurchaseEntryDialog({
    super.key,
    this.isModify = false,
    this.existingData,
  });

  @override
  State<PurchaseEntryDialog> createState() => _PurchaseEntryDialogState();
}

class _PurchaseEntryDialogState extends State<PurchaseEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _lookupFormKey = GlobalKey<FormState>();
  final _factoryFormKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _factoryTableScrollController = ScrollController();
  final FocusNode _dialogFocusNode = FocusNode();
  bool _isSubmitting = false;
  DateTime? _lastSubmitTime;

  // Flag to prevent duplicate submissions
  bool _isEntrySaved = false;
  String? _savedDocId;

  // Regenerating the proforma for an already-saved entry (modify flow)
  bool _isRegeneratingProforma = false;

  // Find-then-edit flow
  bool _entryFound = false;
  bool _isSearching = false;
  String? _docId;
  String? _lookupError;

  // Header fields
  String? _selectedCentre;
  final _reportNoController = TextEditingController();
  final _moistureController = TextEditingController();

  // Farmers Benefitted
  final _farmersDayController = TextEditingController();
  final _farmersProgressiveController = TextEditingController();
  double _previousFarmersProg = 0;

  // Arrivals
  final _dayArrivalsApmcController = TextEditingController();
  final _dayArrivalsOutsideController = TextEditingController();
  final _progArrivalsApmcController = TextEditingController();
  final _progArrivalsOutsideController = TextEditingController();
  double _previousProgApmc = 0;
  double _previousProgOutside = 0;

  // Market Rates
  final _marketRateHighestController = TextEditingController();
  final _marketRateLowestController = TextEditingController();
  final _marketRateAverageController = TextEditingController();
  final _marketSeedRateHighestController = TextEditingController();
  final _marketSeedRateLowestController = TextEditingController();

  // CCI Purchase
  final _cciPurchaseQtlsController = TextEditingController();
  final _cciPurchaseBalesController = TextEditingController();
  final _cciKapasMoistureController = TextEditingController();

  // MSP Value
  final _mspValueDayController = TextEditingController();
  final _mspValueProgController = TextEditingController();
  double _previousMspProg = 0;

  // CCI Rates
  final _cciRateHighestController = TextEditingController();
  final _cciRateLowestController = TextEditingController();
  final _cciRateAverageController = TextEditingController();

  // CCI Details
  final _cciSeedRateController = TextEditingController();
  final _cciOutTurnController = TextEditingController();
  final _cciShortageController = TextEditingController();
  final _cciExpensesController = TextEditingController();
  final _processingCycleController = TextEditingController();
  final _cciPadthaController = TextEditingController();

  // Progressive Purchase - READ ONLY
  final _progPurchaseQtlsController = TextEditingController();
  final _progPurchaseBalesController = TextEditingController();
  final _progPadthaController = TextEditingController();
  final _progAvgRateController = TextEditingController();

  // Bales Pressed
  final _balesPressedTodayController = TextEditingController();
  final _balesPressedProgController = TextEditingController();
  double _previousBalesProg = 0;
  final _totalBalesShiftedController = TextEditingController();

  // Other
  final _sampleSentController = TextEditingController();
  final _heapResultController = TextEditingController();

  List<PurchaseFactoryData> _purchaseFactories = [];

  DateTime _selectedDate = DateTime.now();
  String? _selectedVariety;

  bool _isLoadingPreviousProgressive = false;
  String _debugMessage = '';
  bool _isLoadingReportNo = false;

  // Store original day values when in modify mode to calculate progressive correctly
  double _originalDayApmc = 0;
  double _originalDayOutside = 0;
  int _originalFarmersDay = 0;
  double _originalMspDay = 0;
  int _originalBalesToday = 0;

  @override
  void initState() {
    super.initState();

    if (widget.isModify && widget.existingData != null) {
      _loadExistingData(widget.existingData!);
      _docId = widget.existingData!['id']?.toString();
      _entryFound = true;
      _isEntrySaved = true;
      _savedDocId = _docId;

      // In modify mode, fetch the latest progressive values
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchLatestProgressiveForModify();
        // Also fetch progressive purchase values from proforma
        if (_docId != null) {
          _fetchProgressivePurchaseFromProforma(_docId!);
        }
      });
    } else if (!widget.isModify) {
      _entryFound = true;
      _purchaseFactories = [];
      _isEntrySaved = false;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadDefaultCentre();
        if (_selectedCentre != null &&
            _selectedCentre!.isNotEmpty &&
            _selectedVariety != null &&
            _selectedVariety!.isNotEmpty) {
          await _fetchPreviousProgressive();
          // Also try to fetch progressive purchase from proforma if exists
          await _fetchProgressivePurchaseFromProformaForNewEntry();
        }
      });
    }

    if (!widget.isModify) {
      _dayArrivalsApmcController.addListener(_recalculateProgApmc);
      _dayArrivalsOutsideController.addListener(_recalculateProgOutside);
      _farmersDayController.addListener(_recalculateFarmersProg);
      _mspValueDayController.addListener(_recalculateMspProg);
      _balesPressedTodayController.addListener(_recalculateBalesProg);
    } else {
      // In modify mode, add listeners but with different logic
      _dayArrivalsApmcController.addListener(_recalculateProgApmcModify);
      _dayArrivalsOutsideController.addListener(_recalculateProgOutsideModify);
      _farmersDayController.addListener(_recalculateFarmersProgModify);
      _mspValueDayController.addListener(_recalculateMspProgModify);
      _balesPressedTodayController.addListener(_recalculateBalesProgModify);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_dialogFocusNode);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _factoryTableScrollController.dispose();
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

  // ============================================================
  // RECALCULATION METHODS FOR MODIFY MODE
  // ============================================================

  void _recalculateProgApmcModify() {
    final dayValue = double.tryParse(_dayArrivalsApmcController.text) ?? 0;
    _progArrivalsApmcController.text = _formatNumber(_previousProgApmc + dayValue);
  }

  void _recalculateProgOutsideModify() {
    final dayValue = double.tryParse(_dayArrivalsOutsideController.text) ?? 0;
    _progArrivalsOutsideController.text = _formatNumber(_previousProgOutside + dayValue);
  }

  void _recalculateFarmersProgModify() {
    final dayValue = double.tryParse(_farmersDayController.text) ?? 0;
    _farmersProgressiveController.text = _formatNumber(_previousFarmersProg + dayValue);
  }

  void _recalculateMspProgModify() {
    final dayValue = double.tryParse(_mspValueDayController.text) ?? 0;
    _mspValueProgController.text = _formatNumber(_previousMspProg + dayValue);
  }

  void _recalculateBalesProgModify() {
    final dayValue = double.tryParse(_balesPressedTodayController.text) ?? 0;
    _balesPressedProgController.text = _formatNumber(_previousBalesProg + dayValue);
  }

  void _loadExistingData(Map<String, dynamic> data) {
    final centre = data['centre'] as String?;
    _selectedCentre = (centre != null && centre.isNotEmpty) ? centre : null;
    _reportNoController.text = data['reportNo']?.toString() ?? '';
    _moistureController.text = data['moisture'] ?? '';

    _originalDayApmc = double.tryParse(data['dayArrivalsApmc']?.toString() ?? '0') ?? 0;
    _originalDayOutside = double.tryParse(data['dayArrivalsOutside']?.toString() ?? '0') ?? 0;
    _originalFarmersDay = int.tryParse(data['farmersDay']?.toString() ?? '0') ?? 0;
    _originalMspDay = double.tryParse(data['mspValueDay']?.toString() ?? '0') ?? 0;
    _originalBalesToday = int.tryParse(data['balesPressedToday']?.toString() ?? '0') ?? 0;

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

    if (data['factories'] is List && (data['factories'] as List).isNotEmpty) {
      _purchaseFactories = (data['factories'] as List)
          .map((f) => PurchaseFactoryData.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList();
    } else {
      _purchaseFactories = [
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
      _selectedVariety = data['variety'];
    }
    if (data['date'] != null) {
      _selectedDate = DateTime.parse(data['date']);
    }
  }

  // ============================================================
  // FETCH LATEST PROGRESSIVE FOR MODIFY MODE
  // ============================================================
  Future<void> _fetchLatestProgressiveForModify() async {
    if (_selectedCentre == null || _selectedCentre!.isEmpty) return;
    if (_selectedVariety == null || _selectedVariety!.isEmpty) return;

    setState(() {
      _isLoadingPreviousProgressive = true;
      _debugMessage = 'Fetching latest progressive values...';
    });

    try {
      final response = await ApiService.getLatestProgressiveArrivals(
        type: 'purchase',
        centre: _selectedCentre!,
        variety: _selectedVariety!,
        excludeDocId: _docId,
      );

      if (!mounted) return;

      setState(() {
        _isLoadingPreviousProgressive = false;

        if (response.success && response.data != null) {
          _previousProgApmc = (response.data!['progArrivalsApmc'] as num?)?.toDouble() ?? 0;
          _previousProgOutside = (response.data!['progArrivalsOutside'] as num?)?.toDouble() ?? 0;
          _previousFarmersProg = (response.data!['farmersProgressive'] as num?)?.toDouble() ?? 0;
          _previousMspProg = (response.data!['mspValueProg'] as num?)?.toDouble() ?? 0;
          _previousBalesProg = (response.data!['balesPressedProg'] as num?)?.toDouble() ?? 0;
          _debugMessage = '✅ Loaded latest: APMC=$_previousProgApmc, Outside=$_previousProgOutside';
        } else {
          _previousProgApmc = 0;
          _previousProgOutside = 0;
          _previousFarmersProg = 0;
          _previousMspProg = 0;
          _previousBalesProg = 0;
          _debugMessage = '⚠️ No previous entries found, starting from 0';
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalculateProgApmcModify();
        _recalculateProgOutsideModify();
        _recalculateFarmersProgModify();
        _recalculateMspProgModify();
        _recalculateBalesProgModify();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPreviousProgressive = false;
          _debugMessage = '❌ Error: $e';
        });
      }
    }
  }

  // ============================================================
  // FETCH PROGRESSIVE PURCHASE VALUES FROM PROFORMA
  // This method ONLY fetches the Progressive Purchase values from proforma
  // It does NOT affect any other logic
  // ============================================================
  Future<void> _fetchProgressivePurchaseFromProforma(String purchaseEntryId) async {
    try {
      final response = await ApiService.getProformaByPurchaseEntry(purchaseEntryId);

      if (!mounted) return;

      if (response.success && response.data != null) {
        final proforma = response.data!['proforma'] as Map<String, dynamic>;

        // Extract PROG AVG values directly from proforma
        final quantity = proforma['quantity'] as num? ?? 0;
        final bales = proforma['bales'] as num? ?? 0;
        final padtha = proforma['padtha'] as num? ?? 0;
        final avgRate = proforma['rate'] as num? ?? 0;

        setState(() {
          _progPurchaseQtlsController.text = quantity.toString();
          _progPurchaseBalesController.text = bales.toString();
          _progPadthaController.text = padtha.toStringAsFixed(2);
          _progAvgRateController.text = avgRate.toStringAsFixed(2);
        });

        debugLog('✅ Progressive Purchase fetched from proforma: Qty=$quantity, Bales=$bales, Padtha=$padtha, Rate=$avgRate');
      } else {
        debugLog('⚠️ No proforma found for progressive purchase values');
      }
    } catch (e) {
      debugLog('❌ Error fetching proforma data: $e');
    }
  }

  // ============================================================
  // FETCH PROGRESSIVE PURCHASE FROM PROFORMA FOR NEW ENTRY
  // ============================================================
  Future<void> _fetchProgressivePurchaseFromProformaForNewEntry() async {
    if (_selectedCentre == null || _selectedCentre!.isEmpty) return;
    if (_selectedVariety == null || _selectedVariety!.isEmpty) return;

    try {
      // Get all proformas for this user
      final proformaResponse = await ApiService.getProformas();

      if (!mounted) return;

      if (proformaResponse.success && proformaResponse.data != null) {
        final proformas = proformaResponse.data!['proformas'] as List? ?? [];

        // Find the latest proforma for this centre+variety
        Map<String, dynamic>? latestProforma;
        for (final proforma in proformas) {
          if (proforma['centre'] == _selectedCentre &&
              proforma['variety'] == _selectedVariety) {
            if (latestProforma == null) {
              latestProforma = proforma;
            }
          }
        }

        if (latestProforma != null) {
          // Found a proforma - use its PROG AVG values
          final quantity = latestProforma['quantity'] as num? ?? 0;
          final bales = latestProforma['bales'] as num? ?? 0;
          final padtha = latestProforma['padtha'] as num? ?? 0;
          final avgRate = latestProforma['rate'] as num? ?? 0;

          setState(() {
            _progPurchaseQtlsController.text = quantity.toString();
            _progPurchaseBalesController.text = bales.toString();
            _progPadthaController.text = padtha.toStringAsFixed(2);
            _progAvgRateController.text = avgRate.toStringAsFixed(2);
          });

          debugLog('✅ Progressive Purchase fetched from proforma for new entry: Qty=$quantity, Bales=$bales, Padtha=$padtha, Rate=$avgRate');
        }
      }
    } catch (e) {
      debugLog('❌ Error fetching proforma for new entry: $e');
    }
  }

  Future<void> _loadDefaultCentre() async {
    if (_selectedCentre != null) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(ReportConstants.prefKeyLastCentre);
    if (!mounted) return;
    if (saved != null && ReportConstants.centres.contains(saved)) {
      setState(() => _selectedCentre = saved);
    }
  }

  Future<void> _rememberCentre(String centre) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ReportConstants.prefKeyLastCentre, centre);
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  void _resetReportNoToDefault() {
    _reportNoController.text = '';
  }

  void _recalculateProgApmc() {
    final dayValue = double.tryParse(_dayArrivalsApmcController.text) ?? 0;
    _progArrivalsApmcController.text = _formatNumber(_previousProgApmc + dayValue);
  }

  void _recalculateProgOutside() {
    final dayValue = double.tryParse(_dayArrivalsOutsideController.text) ?? 0;
    _progArrivalsOutsideController.text = _formatNumber(_previousProgOutside + dayValue);
  }

  void _recalculateFarmersProg() {
    final dayValue = double.tryParse(_farmersDayController.text) ?? 0;
    _farmersProgressiveController.text = _formatNumber(_previousFarmersProg + dayValue);
  }

  void _recalculateMspProg() {
    final dayValue = double.tryParse(_mspValueDayController.text) ?? 0;
    _mspValueProgController.text = _formatNumber(_previousMspProg + dayValue);
  }

  void _recalculateBalesProg() {
    final dayValue = double.tryParse(_balesPressedTodayController.text) ?? 0;
    _balesPressedProgController.text = _formatNumber(_previousBalesProg + dayValue);
  }

  // ============================================================
  // FETCH PREVIOUS PROGRESSIVE - for new entry creation
  // THIS LOGIC REMAINS UNCHANGED
  // ============================================================
  Future<void> _fetchPreviousProgressive() async {
    if (widget.isModify) return;

    if (_selectedCentre == null || _selectedCentre!.isEmpty) {
      setState(() {
        _isLoadingPreviousProgressive = false;
        _debugMessage = 'No centre selected';
      });
      return;
    }

    if (_selectedVariety == null || _selectedVariety!.isEmpty) {
      setState(() {
        _isLoadingPreviousProgressive = false;
        _debugMessage = 'No variety selected';
      });
      return;
    }

    setState(() {
      _isLoadingPreviousProgressive = true;
      _debugMessage = 'Fetching data...';
    });

    final requestedCentre = _selectedCentre;
    final requestedVariety = _selectedVariety;

    try {
      final response = await ApiService.getLatestProgressiveArrivals(
        type: 'purchase',
        centre: _selectedCentre!,
        variety: _selectedVariety!,
      );

      if (!mounted) return;
      if (requestedCentre != _selectedCentre || requestedVariety != _selectedVariety) return;

      setState(() {
        _isLoadingPreviousProgressive = false;

        if (response.success && response.data != null) {
          _previousProgApmc = (response.data!['progArrivalsApmc'] as num?)?.toDouble() ?? 0;
          _previousProgOutside = (response.data!['progArrivalsOutside'] as num?)?.toDouble() ?? 0;
          _previousFarmersProg = (response.data!['farmersProgressive'] as num?)?.toDouble() ?? 0;
          _previousMspProg = (response.data!['mspValueProg'] as num?)?.toDouble() ?? 0;
          _previousBalesProg = (response.data!['balesPressedProg'] as num?)?.toDouble() ?? 0;
          _debugMessage = '✅ Loaded: APMC=$_previousProgApmc, Outside=$_previousProgOutside';
        } else {
          _previousProgApmc = 0;
          _previousProgOutside = 0;
          _previousFarmersProg = 0;
          _previousMspProg = 0;
          _previousBalesProg = 0;
          _debugMessage = '⚠️ No previous values found, starting from 0';
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
      if (mounted && requestedCentre == _selectedCentre && requestedVariety == _selectedVariety) {
        setState(() {
          _isLoadingPreviousProgressive = false;
          _debugMessage = '❌ Error: $e';
        });
      }
    }
  }

  Future<void> _findEntry() async {
    if (!_lookupFormKey.currentState!.validate()) return;
    if (_selectedCentre == null) return;

    final reportNo = int.tryParse(_reportNoController.text);
    if (reportNo == null) return;

    setState(() {
      _isSearching = true;
      _lookupError = null;
    });

    final normalizedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    final response = await ApiService.findEntry(
      type: 'purchase',
      centre: _selectedCentre!,
      reportNo: reportNo,
      date: normalizedDate,
      variety: _selectedVariety,
    );

    if (!mounted) return;

    if (response.success && response.data != null) {
      final entry = Map<String, dynamic>.from(response.data!['entry'] as Map);
      setState(() {
        _isSearching = false;
        _lookupError = null;
        _docId = entry['id']?.toString();
        _entryFound = true;
        _isEntrySaved = true;
        _savedDocId = _docId;
      });
      _loadExistingData(entry);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchLatestProgressiveForModify();
        // Auto-fetch progressive purchase values from proforma
        if (_docId != null) {
          _fetchProgressivePurchaseFromProforma(_docId!);
        }
      });
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
      _isEntrySaved = false;
      _savedDocId = null;
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
            colorScheme: const ColorScheme.light(primary: Color(0xFF0F172A)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      if (!widget.isModify) {
        await _fetchPreviousProgressive();
        await _fetchProgressivePurchaseFromProformaForNewEntry();
      }
    }
  }

  void _showCelebration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isModify ? 'Report Updated Successfully!' : 'Report Created Successfully!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text('Redirecting to dashboard...', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A))),
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

  void _showProformaSuccessDialog(Map<String, dynamic> proformaData, {bool isUpdate = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
            ),
            const SizedBox(width: 12),
            Text(isUpdate ? 'Proforma Updated!' : 'Proforma Generated!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProformaSummaryRow('Centre', proformaData['centre']),
            _buildProformaSummaryRow('Variety', proformaData['variety'] ?? '-'),
            _buildProformaSummaryRow('Date', DateFormat('dd/MM/yyyy').format(_selectedDate)),
            _buildProformaSummaryRow('Quantity', '${proformaData['quantity']} Quintals'),
            _buildProformaSummaryRow('Rate', '₹${proformaData['rate']}'),
            _buildProformaSummaryRow('Amount', '₹${proformaData['amount'].toStringAsFixed(2)}'),
            _buildProformaSummaryRow('Farmers', proformaData['farmers'].toString()),
            _buildProformaSummaryRow('Moisture', '${proformaData['moisture']}%'),
            _buildProformaSummaryRow('Seed', '${proformaData['seed'].toStringAsFixed(2)}%'),
            const Divider(),
            _buildProformaSummaryRow('Seed Value', '₹${proformaData['seedValue'].toStringAsFixed(2)}', isBold: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _viewProforma(proformaData['purchaseEntryId']);
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('View Full Proforma'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProformaSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  void _viewProforma(String purchaseEntryId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProformaViewScreen(
          purchaseEntryId: purchaseEntryId,
        ),
      ),
    );
  }

  // ============================================================
  // SHOW DUPLICATE ERROR DIALOG
  // ============================================================
  void _showDuplicateErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Operation Not Possible',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A report with the same details already exists.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Centre', _selectedCentre ?? '-'),
                  _buildDetailRow('Report No.', _reportNoController.text),
                  _buildDetailRow('Date', CommonFormWidgets.formatDate(_selectedDate)),
                  _buildDetailRow('Variety', _selectedVariety ?? '-'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please change at least one of the above fields to create a new report.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHECK FOR EXISTING ENTRY
  // ============================================================
  Future<bool> _checkEntryExists() async {
    if (widget.isModify) return false;

    final reportNo = int.tryParse(_reportNoController.text) ?? 0;
    if (reportNo == 0) return false;

    final normalizedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    try {
      final response = await ApiService.checkEntryExists(
        type: 'purchase',
        centre: _selectedCentre!,
        reportNo: reportNo,
        date: normalizedDate,
        variety: _selectedVariety ?? '',
      );

      if (response.success && response.data != null) {
        return response.data!['exists'] == true;
      }
      return false;
    } catch (e) {
      debugLog('❌ Error checking entry: $e');
      return false;
    }
  }

  Map<String, dynamic> _buildPurchaseData() {
    return {
      'reportType': ReportType.dailyPurchase.label,
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
      'cciKapasMoisture': double.tryParse(_cciKapasMoistureController.text) ?? 0,
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
      'cciPadtha': double.tryParse(_cciPadthaController.text) ?? 0,
      'progPurchaseQtls': double.tryParse(_progPurchaseQtlsController.text) ?? 0,
      'progPurchaseBales': int.tryParse(_progPurchaseBalesController.text) ?? 0,
      'progPadtha': int.tryParse(_progPadthaController.text) ?? 0,
      'progAvgRate': int.tryParse(_progAvgRateController.text) ?? 0,
      'balesPressedToday': int.tryParse(_balesPressedTodayController.text) ?? 0,
      'balesPressedProg': int.tryParse(_balesPressedProgController.text) ?? 0,
      'totalBalesShifted': int.tryParse(_totalBalesShiftedController.text) ?? 0,
      'sampleSent': _sampleSentController.text,
      'heapResult': _heapResultController.text,
      'factories': _purchaseFactories.map((f) => f.toJson()).toList(),
    };
  }

  void _autoFillProgressive() {
    final qtls = double.tryParse(_cciPurchaseQtlsController.text) ?? 0;
    final bales = int.tryParse(_cciPurchaseBalesController.text) ?? 0;
    final padtha = double.tryParse(_cciPadthaController.text) ?? 0;
    final avgRate = double.tryParse(_cciRateAverageController.text) ?? 0;

    setState(() {
      _progPurchaseQtlsController.text = qtls.toString();
      _progPurchaseBalesController.text = bales.toString();
      _progPadthaController.text = padtha.toString();
      _progAvgRateController.text = avgRate.toString();
    });
  }

  // ============================================================
  // Builds the proforma payload from the CURRENT form values.
  // ============================================================
  Map<String, dynamic>? _buildProformaPayload(String purchaseEntryId) {
    final quantity = double.tryParse(_cciPurchaseQtlsController.text) ?? 0;
    final rate = double.tryParse(_cciRateAverageController.text) ?? 0;
    if (quantity <= 0 || rate <= 0) return null;
    if (_selectedCentre == null || _selectedCentre!.isEmpty) return null;

    final farmers = int.tryParse(_farmersDayController.text) ?? 0;
    final moisture = double.tryParse(_cciKapasMoistureController.text) ?? 0;
    final shortage = double.tryParse(_cciShortageController.text) ?? 0;
    final padtha = double.tryParse(_cciPadthaController.text) ?? 0;
    final outTurn = double.tryParse(_cciOutTurnController.text) ?? 0;

    final bales = int.tryParse(_cciPurchaseBalesController.text) ?? 0;
    double heap = 0;
    for (final factory in _purchaseFactories) {
      heap += factory.heapQty;
    }

    final amount = quantity * rate;
    final moistureValue = moisture * quantity;
    final shortageValue = shortage * quantity;
    final padthaValue = padtha * quantity;
    final outTurnValue = outTurn * quantity;
    final seed = 100 - (outTurn + shortage);
    final seedValue = seed * quantity;

    return {
      'centre': _selectedCentre!,
      'variety': _selectedVariety ?? '',
      'date': _selectedDate.toIso8601String(),
      'purchaseEntryId': purchaseEntryId,
      'quantity': quantity,
      'rate': rate,
      'amount': amount,
      'farmers': farmers,
      'moisture': moisture,
      'moistureValue': moistureValue,
      'shortage': shortage,
      'shortageValue': shortageValue,
      'padtha': padtha,
      'padthaValue': padthaValue,
      'outTurn': outTurn,
      'outTurnValue': outTurnValue,
      'seed': seed,
      'seedValue': seedValue,
      'bales': bales,
      'heap': heap,
    };
  }

  // ============================================================
  // UPDATE & REGENERATE PROFORMA
  // ============================================================
  Future<void> _regenerateProforma() async {
    if (_isSubmitting || _isRegeneratingProforma) return;

    if (_docId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save the entry first before regenerating the proforma'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedCentre == null || _selectedCentre!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a centre'), backgroundColor: Colors.red),
      );
      return;
    }

    _autoFillProgressive();

    final proformaData = _buildProformaPayload(_docId!);
    if (proformaData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid quantity and average rate to regenerate the proforma'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isRegeneratingProforma = true);

    try {
      final entryResponse = await ApiService.updateEntry(_docId!, _buildPurchaseData());

      if (!mounted) return;

      if (!entryResponse.success) {
        setState(() => _isRegeneratingProforma = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update entry: ${entryResponse.message}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final proformaResponse = await ApiService.saveProforma(proformaData);

      if (!mounted) return;

      setState(() => _isRegeneratingProforma = false);

      if (proformaResponse.success) {
        // Fetch and fill progressive purchase values from the updated proforma
        await _fetchProgressivePurchaseFromProforma(_docId!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Proforma regenerated with the latest values'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        _showProformaSuccessDialog(proformaData, isUpdate: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to regenerate proforma: ${proformaResponse.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRegeneratingProforma = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error regenerating proforma: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ============================================================
  // SAVE PROFORMA - Saves initial entry
  // ============================================================
  Future<void> _saveProforma() async {
    final now = DateTime.now();
    if (_lastSubmitTime != null &&
        now.difference(_lastSubmitTime!).inMilliseconds < 2000) {
      return;
    }

    if (_isEntrySaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry already saved! You can add details and click Submit to update.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedCentre == null || _selectedCentre!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a centre'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_reportNoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Report No.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedVariety == null || _selectedVariety!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a variety'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final quantity = double.tryParse(_cciPurchaseQtlsController.text) ?? 0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity in CCI Purchase Quintals'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final rate = double.tryParse(_cciRateAverageController.text) ?? 0;
    if (rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid average rate'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _lastSubmitTime = now;

    final exists = await _checkEntryExists();
    if (exists) {
      _showDuplicateErrorDialog();
      _lastSubmitTime = null;
      return;
    }

    _autoFillProgressive();

    setState(() => _isSubmitting = true);

    try {
      final purchaseData = _buildPurchaseData();

      final response = await ApiService.savePurchaseEntry(purchaseData);

      if (!mounted) {
        setState(() => _isSubmitting = false);
        return;
      }

      if (response.success && response.data != null) {
        final entryId = response.data!['id'] as String?;
        _savedDocId = entryId;
        _docId = entryId;

        setState(() {
          _isEntrySaved = true;
        });

        debugLog('✅ Purchase entry saved with ID: $entryId');

        final proformaData = _buildProformaPayload(entryId ?? '');

        if (proformaData == null) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry saved, but the proforma could not be generated — check quantity/rate'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        final proformaResponse = await ApiService.saveProforma(proformaData);

        if (!mounted) {
          setState(() => _isSubmitting = false);
          return;
        }

        setState(() => _isSubmitting = false);

        if (proformaResponse.success) {
          // Fetch and fill progressive purchase values from the generated proforma
          await _fetchProgressivePurchaseFromProforma(entryId ?? '');
          _showProformaSuccessDialog(proformaData);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save proforma: ${proformaResponse.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save entry: ${response.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // SUBMIT FORM
  // ============================================================
  void _submitForm() async {
    final now = DateTime.now();
    if (_lastSubmitTime != null &&
        now.difference(_lastSubmitTime!).inMilliseconds < 2000) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the highlighted fields before updating'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _lastSubmitTime = now;

    setState(() => _isSubmitting = true);

    final data = _buildPurchaseData();
    final wasExistingEntry = (_isEntrySaved || widget.isModify) && _docId != null;

    final ApiResponse response;

    if (_isEntrySaved && _docId != null) {
      response = await ApiService.updateEntry(_docId!, data);
    } else if (widget.isModify && _docId != null) {
      response = await ApiService.updateEntry(_docId!, data);
    } else {
      final exists = await _checkEntryExists();
      if (exists) {
        setState(() => _isSubmitting = false);
        _showDuplicateErrorDialog();
        return;
      }
      response = await ApiService.savePurchaseEntry(data);
    }

    if (!mounted) return;

    if (response.success && wasExistingEntry) {
      final proformaSync = _buildProformaPayload(_docId!);
      if (proformaSync != null) {
        final syncResponse = await ApiService.saveProforma(proformaSync);
        if (!syncResponse.success) {
          debugLog('⚠️ Failed to sync proforma after update: ${syncResponse.message}');
        } else {
          debugLog('✅ Proforma synced after update');
          // Fetch and fill progressive purchase values after sync
          await _fetchProgressivePurchaseFromProforma(_docId!);
        }
      }
    }

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (response.success) {
      if (response.data != null && response.data!['id'] != null) {
        _docId = response.data!['id'] as String?;
        _savedDocId = _docId;
        _isEntrySaved = true;
      }
      _showCelebration();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
      );
    }
  }

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

  // -------------------- Factory dialog helpers --------------------

  void _openAddPurchaseFactoryDialog() => _showPurchaseFactoryFormDialog(null);
  void _openEditPurchaseFactoryDialog(int index) => _showPurchaseFactoryFormDialog(_purchaseFactories[index]);

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
            key: _factoryFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CommonFormWidgets.textField(
                    controller: nameController,
                    label: 'Factory Name',
                    hint: 'e.g., A Yesh Patil Cotton Company',
                    icon: Icons.factory,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CommonFormWidgets.textField(
                          controller: heapNoController,
                          label: 'Heap No.',
                          hint: 'e.g., 101',
                          icon: Icons.numbers,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CommonFormWidgets.textField(
                          controller: heapQtyController,
                          label: 'Heap Qty',
                          hint: 'Quintals',
                          icon: Icons.scale,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CommonFormWidgets.textField(
                          controller: farmersController,
                          label: 'Farmers Benefitted',
                          hint: 'e.g., 2',
                          icon: Icons.people,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CommonFormWidgets.textField(
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
                        child: CommonFormWidgets.textField(
                          controller: soldController,
                          label: 'Ready Seed Sold',
                          hint: 'e.g., 0',
                          icon: Icons.sell,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CommonFormWidgets.textField(
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
                  CommonFormWidgets.textField(
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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (_factoryFormKey.currentState!.validate()) {
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
                    final index = _purchaseFactories.indexOf(factoryData);
                    _purchaseFactories[index] = factory;
                  } else {
                    _purchaseFactories.add(factory);
                  }
                });

                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: isEditing ? const Color(0xFFF59E0B) : const Color(0xFF059669)),
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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => _purchaseFactories.removeAt(index));
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
    if (_purchaseFactories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFF8FAFC),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.factory_outlined, size: 40, color: Color(0xFF94A3B8)),
              SizedBox(height: 8),
              Text('No factories added yet', style: TextStyle(color: Color(0xFF64748B))),
              Text('Click "Add Factory" to add one', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(12)),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: Scrollbar(
          controller: _factoryTableScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _factoryTableScrollController,
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
              rows: _purchaseFactories.asMap().entries.map((entry) {
                final index = entry.key;
                final factory = entry.value;
                return DataRow(cells: [
                  DataCell(Text('${index + 1}')),
                  DataCell(Text(factory.factoryName)),
                  DataCell(Text(factory.heapNo.toString())),
                  DataCell(Text(factory.heapQty.toString())),
                  DataCell(Text(factory.seedFarmers.toString())),
                  DataCell(Text(factory.seedRealisable.toString())),
                  DataCell(Text(factory.readySeedSold.toString())),
                  DataCell(Text(factory.readySeedUnsold.toString())),
                  DataCell(Text(factory.baseRate.toString())),
                  DataCell(Row(
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
                  )),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------- Build --------------------

  @override
  Widget build(BuildContext context) {
    if (widget.isModify && !_entryFound) {
      return FindEntryDialog(
        entryTypeLabel: 'Purchase',
        headerIcon: Icons.shopping_basket_rounded,
        headerColor: const Color(0xFFE0F2FE),
        formKey: _lookupFormKey,
        focusNode: _dialogFocusNode,
        selectedCentre: _selectedCentre,
        onCentreChanged: (v) => setState(() => _selectedCentre = v),
        selectedVariety: _selectedVariety,
        varietyOptions: ReportConstants.varieties,
        onVarietyChanged: (v) => setState(() => _selectedVariety = v),
        reportNoController: _reportNoController,
        selectedDate: _selectedDate,
        onDateTap: () => _selectDate(context),
        lookupError: _lookupError,
        isSearching: _isSearching,
        onFind: _findEntry,
      );
    }

    final title = widget.isModify ? 'Modify' : 'Add';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Focus(
        focusNode: _dialogFocusNode,
        autofocus: true,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
            const SingleActivator(LogicalKeyboardKey.arrowUp): _scrollUp,
            const SingleActivator(LogicalKeyboardKey.arrowDown): _scrollDown,
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxWidth: 700,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.shopping_basket_rounded,
                                color: Color(0xFF0F172A),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '$title Purchase Entry',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            CommonFormWidgets.closeButton(context),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Main Content
                        if (widget.isModify)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                CommonFormWidgets.sectionHeader('Header Information'),
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
                          CommonFormWidgets.sectionHeader('Header Information'),

                        CommonFormWidgets.centreDropdown(
                          selectedCentre: _selectedCentre,
                          readOnly: widget.isModify,
                          onChanged: (value) {
                            setState(() {
                              _selectedCentre = value;
                              _previousProgApmc = 0;
                              _previousProgOutside = 0;
                              _previousFarmersProg = 0;
                              _previousMspProg = 0;
                              _previousBalesProg = 0;
                              _debugMessage = '';
                              _progArrivalsApmcController.text = '';
                              _progArrivalsOutsideController.text = '';
                              _farmersProgressiveController.text = '';
                              _mspValueProgController.text = '';
                              _balesPressedProgController.text = '';
                              _resetReportNoToDefault();
                              _isEntrySaved = false;
                            });
                            if (value != null) {
                              _rememberCentre(value);
                              if (_selectedVariety != null && _selectedVariety!.isNotEmpty) {
                                if (widget.isModify) {
                                  _fetchLatestProgressiveForModify();
                                } else {
                                  _fetchPreviousProgressive();
                                  _fetchProgressivePurchaseFromProformaForNewEntry();
                                }
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 10),

                        CommonFormWidgets.textField(
                          controller: _reportNoController,
                          label: 'Report No.',
                          hint: 'e.g., 1',
                          icon: Icons.numbers,
                          keyboardType: TextInputType.number,
                          readOnly: widget.isModify,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter report number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),

                        InkWell(
                          onTap: widget.isModify ? null : () => _selectDate(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Color(0xFF64748B), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Date: ${CommonFormWidgets.formatDate(_selectedDate)}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        DropdownButtonFormField<String>(
                          initialValue: _selectedVariety,
                          decoration: InputDecoration(
                            labelText: 'Variety',
                            hintText: 'Select variety',
                            prefixIcon: const Icon(Icons.eco, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          items: ReportConstants.varieties.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedVariety = value;
                              _previousProgApmc = 0;
                              _previousProgOutside = 0;
                              _previousFarmersProg = 0;
                              _previousMspProg = 0;
                              _previousBalesProg = 0;
                              _debugMessage = '';
                              _progArrivalsApmcController.text = '';
                              _progArrivalsOutsideController.text = '';
                              _farmersProgressiveController.text = '';
                              _mspValueProgController.text = '';
                              _balesPressedProgController.text = '';
                              _isEntrySaved = false;
                            });
                            if (value != null &&
                                _selectedCentre != null &&
                                _selectedCentre!.isNotEmpty) {
                              if (widget.isModify) {
                                _fetchLatestProgressiveForModify();
                              } else {
                                _fetchPreviousProgressive();
                                _fetchProgressivePurchaseFromProformaForNewEntry();
                              }
                            }
                          },
                          validator: (value) => value == null ? 'Please select a variety' : null,
                        ),
                        const SizedBox(height: 10),

                        CommonFormWidgets.textField(
                          controller: _moistureController,
                          label: 'Moisture Percentage (%)',
                          hint: 'e.g., 8-20%',
                          icon: Icons.water_drop,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter moisture percentage';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Arrivals Section
                        CommonFormWidgets.sectionHeader('Arrivals'),
                        if (!widget.isModify) ...[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Progressive totals are calculated automatically from '
                                  'the last entry for this centre + variety + today\'s values.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ),
                          if (_debugMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                _debugMessage,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _debugMessage.contains('✅')
                                      ? Colors.green
                                      : _debugMessage.contains('⚠️')
                                      ? Colors.orange
                                      : _debugMessage.contains('❌')
                                      ? Colors.red
                                      : Colors.grey,
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _dayArrivalsApmcController,
                                label: 'Day APMC',
                                hint: 'Quintals/Bales',
                                icon: Icons.local_shipping,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _dayArrivalsOutsideController,
                                label: 'Day Outside',
                                hint: 'Quintals/Bales',
                                icon: Icons.local_shipping_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _progArrivalsApmcController,
                                label: 'Prog APMC',
                                hint: _isLoadingPreviousProgressive ? 'Loading previous total...' : 'Quintals/Bales',
                                icon: Icons.trending_up,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _progArrivalsOutsideController,
                                label: 'Prog Outside',
                                hint: _isLoadingPreviousProgressive ? 'Loading previous total...' : 'Quintals/Bales',
                                icon: Icons.trending_up_outlined,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Market Rates
                        CommonFormWidgets.sectionHeader('Market Rates (Kapas Rate in Quintals)'),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _marketRateHighestController,
                                label: 'Highest',
                                hint: 'e.g., 7785.6',
                                icon: Icons.arrow_upward,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _marketRateAverageController,
                                label: 'Average',
                                hint: 'e.g., 7200',
                                icon: Icons.linear_scale,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        CommonFormWidgets.textField(
                          controller: _marketRateLowestController,
                          label: 'Lowest',
                          hint: 'e.g., 7000',
                          icon: Icons.arrow_downward,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 10),

                        const Text('Market Seed Rate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _marketSeedRateHighestController,
                                label: 'Highest',
                                hint: 'e.g., 3700',
                                icon: Icons.arrow_upward,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _marketSeedRateLowestController,
                                label: 'Lowest',
                                hint: 'e.g., 3600',
                                icon: Icons.arrow_downward,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // CCI Purchase
                        CommonFormWidgets.sectionHeader('CCI Purchase'),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _cciPurchaseQtlsController,
                                label: 'Quintals',
                                hint: 'e.g., 109.2',
                                icon: Icons.scale,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _cciPurchaseBalesController,
                                label: 'Bales',
                                hint: 'e.g., 22',
                                icon: Icons.inventory,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        CommonFormWidgets.textField(
                          controller: _cciKapasMoistureController,
                          label: 'Kapas Moisture %',
                          hint: 'e.g., 12',
                          icon: Icons.water_drop,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),

                        // MSP Value
                        CommonFormWidgets.sectionHeader('MSP Value'),
                        if (!widget.isModify)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                              'Progressive MSP is auto-calculated from previous entry + today\'s MSP value',
                              style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _mspValueDayController,
                                label: 'Day Wise',
                                hint: 'e.g., 850187.52',
                                icon: Icons.today,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _mspValueProgController,
                                label: 'Progressive',
                                hint: _isLoadingPreviousProgressive ? 'Loading previous total...' : 'e.g., 850187.52',
                                icon: Icons.trending_up,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                readOnly: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Farmers Benefitted
                        CommonFormWidgets.sectionHeader('Farmers Benefitted'),
                        if (!widget.isModify)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                              'Progressive Farmers is auto-calculated from previous entry + today\'s farmers',
                              style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _farmersDayController,
                                label: 'Day Wise',
                                hint: 'e.g., 2',
                                icon: Icons.people,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _farmersProgressiveController,
                                label: 'Progressive',
                                hint: _isLoadingPreviousProgressive ? 'Loading previous total...' : 'e.g., 2',
                                icon: Icons.people_outline,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // CCI Rates
                        CommonFormWidgets.sectionHeader('CCI Rates (Kapas Rate in Quintals)'),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _cciRateHighestController,
                                label: 'Highest',
                                hint: 'e.g., 7785.6',
                                icon: Icons.arrow_upward,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _cciRateAverageController,
                                label: 'Average',
                                hint: 'e.g., 7785.6',
                                icon: Icons.linear_scale,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        CommonFormWidgets.textField(
                          controller: _cciRateLowestController,
                          label: 'Lowest',
                          hint: 'e.g., 7785.6',
                          icon: Icons.arrow_downward,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 14),

                        // CCI Details
                        CommonFormWidgets.sectionHeader('CCI Details'),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _cciSeedRateController,
                                label: 'Seed Rate',
                                hint: 'e.g., 3700',
                                icon: Icons.attach_money,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _cciOutTurnController,
                                label: 'Out Turn',
                                hint: 'e.g., 0.33',
                                icon: Icons.percent,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _cciShortageController,
                                label: 'Shortage',
                                hint: 'e.g., 0.035',
                                icon: Icons.warning_amber_rounded,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _cciExpensesController,
                                label: 'Expenses',
                                hint: 'e.g., 4050',
                                icon: Icons.money_off,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _processingCycleController,
                                label: 'Processing Cycle',
                                hint: 'e.g., 7 days',
                                icon: Icons.autorenew,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _cciPadthaController,
                                label: 'Padtha',
                                hint: 'e.g., 62706',
                                icon: Icons.receipt,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ============ SAVE / REGENERATE PROFORMA BUTTON ============
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (_isSubmitting || _isRegeneratingProforma)
                                    ? null
                                    : (_isEntrySaved ? _regenerateProforma : _saveProforma),
                                icon: _isRegeneratingProforma
                                    ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                                    : Icon(
                                  _isEntrySaved ? Icons.refresh : Icons.save,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                label: Text(
                                  _isRegeneratingProforma
                                      ? 'Regenerating...'
                                      : (_isEntrySaved
                                      ? 'Update & Regenerate Proforma'
                                      : 'Save & Generate Proforma'),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Refresh Progressive Values Button (only shown when entry is saved)
                        if (_isEntrySaved) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: (_savedDocId != null && _docId != null)
                                      ? () => _fetchProgressivePurchaseFromProforma(_docId!)
                                      : null,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Refresh Progressive Values from Proforma'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0F172A),
                                    side: const BorderSide(color: Color(0xFF0F172A)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Progressive Purchase
                        CommonFormWidgets.sectionHeader('Progressive Purchase'),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Values are auto-filled from CCI Purchase when generating Proforma',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _progPurchaseQtlsController,
                                label: 'Quintals',
                                hint: 'Auto-filled',
                                icon: Icons.scale,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                readOnly: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _progPurchaseBalesController,
                                label: 'Bales',
                                hint: 'Auto-filled',
                                icon: Icons.inventory,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _progPadthaController,
                                label: 'Padtha',
                                hint: 'Auto-filled',
                                icon: Icons.receipt_long,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _progAvgRateController,
                                label: 'Avg Rate',
                                hint: 'Auto-filled',
                                icon: Icons.calculate,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Bales Pressed
                        CommonFormWidgets.sectionHeader('Bales Pressed'),
                        if (!widget.isModify)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                              'Progressive Bales is auto-calculated from previous entry + today\'s bales',
                              style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _balesPressedTodayController,
                                label: 'Today',
                                hint: 'e.g., 0',
                                icon: Icons.today,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _balesPressedProgController,
                                label: 'Progressive',
                                hint: _isLoadingPreviousProgressive ? 'Loading previous total...' : 'e.g., 0',
                                icon: Icons.trending_up,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        CommonFormWidgets.textField(
                          controller: _totalBalesShiftedController,
                          label: 'Total Bales Shifted to Godown',
                          hint: 'e.g., 0',
                          icon: Icons.warehouse,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),

                        // Other Details
                        CommonFormWidgets.sectionHeader('Other Details'),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _sampleSentController,
                                label: 'Sample Sent to B.O',
                                hint: 'e.g., - or Yes',
                                icon: Icons.send,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _heapResultController,
                                label: 'Heap Result Sent to B.O',
                                hint: 'e.g., - or Yes',
                                icon: Icons.check_circle_outline,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Factory Details
                        CommonFormWidgets.sectionHeaderWithAction(
                          'Factory Details',
                          actionLabel: 'Add Factory',
                          onAction: _openAddPurchaseFactoryDialog,
                        ),
                        const SizedBox(height: 10),
                        _buildPurchaseFactoryListView(),
                        const SizedBox(height: 14),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isEntrySaved ? const Color(0xFF0F172A) : const Color(0xFF0F172A),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                                    : Text(
                                  _isEntrySaved ? 'Update Report' : (widget.isModify ? 'Update' : 'Submit'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}