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

  // Only 3 varieties as per Excel
  final List<String> _varieties = ['BB MOD', 'BB SPL MOD', 'MECH'];
  String? _selectedVariety;

  // Fields from Excel template
  final _farmersDayController = TextEditingController();
  final _arrivalsBalesController = TextEditingController();
  final _cciPurchaseQtlsController = TextEditingController();
  final _cciPurchaseBalesController = TextEditingController();
  final _avgKapasRateController = TextEditingController();
  final _budgetedLintController = TextEditingController();
  final _budgetedShortageController = TextEditingController();
  final _cottonSeedRateController = TextEditingController();
  final _processingCycleController = TextEditingController();
  final _proformaExpensesController = TextEditingController();
  final _budgetedPadthaController = TextEditingController();
  final _dayPressedBalesController = TextEditingController();
  final _marketHighestRateController = TextEditingController();
  final _marketLowestRateController = TextEditingController();
  final _cciHighestRateController = TextEditingController();
  final _cciLowestRateController = TextEditingController();

  // Progressive fields (auto-calculated or read-only)
  final _progPressedBalesController = TextEditingController();
  final _progPurchaseQtlsController = TextEditingController();
  final _progPurchaseBalesController = TextEditingController();
  final _progFarmersController = TextEditingController();

  // Previous progressive values for calculation
  double _previousProgPressedBales = 0;
  double _previousProgPurchaseQtls = 0;
  double _previousProgPurchaseBales = 0;
  double _previousProgFarmers = 0;

  // ⭐ NEW: Progressive values for the OTHER two varieties.
  // Saved into the document as `otherVarietiesProgressive` so the
  // preview & export can render all three columns even when the user
  // only filled in data for their own variety.
  Map<String, Map<String, double>> _otherVarietiesProgressive = {};

  // Store original values for modify mode
  double _originalPressedBales = 0;
  double _originalPurchaseQtls = 0;
  double _originalPurchaseBales = 0;
  double _originalFarmers = 0;

  // Factory data with progressive purchase values
  List<PurchaseFactoryProgData> _purchaseFactories = [];

  DateTime _selectedDate = DateTime.now();
  bool _isLoadingPreviousProgressive = false;
  String _debugMessage = '';
  bool _isLoadingReportNo = false;

  @override
  void initState() {
    super.initState();

    if (widget.isModify && widget.existingData != null) {
      _loadExistingData(widget.existingData!);
      _docId = widget.existingData!['id']?.toString();
      _entryFound = true;
      _isEntrySaved = true;
      _savedDocId = _docId;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchLatestProgressiveForModify();
        _fetchOtherVarietiesProgressive();
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
          await _fetchOtherVarietiesProgressive();
        }
      });
    }

    if (!widget.isModify) {
      _dayPressedBalesController.addListener(_recalculateProgPressedBales);
      _cciPurchaseQtlsController.addListener(_recalculateProgPurchaseQtls);
      _cciPurchaseBalesController.addListener(_recalculateProgPurchaseBales);
      _farmersDayController.addListener(_recalculateProgFarmers);
    } else {
      _dayPressedBalesController.addListener(_recalculateProgPressedBalesModify);
      _cciPurchaseQtlsController.addListener(_recalculateProgPurchaseQtlsModify);
      _cciPurchaseBalesController.addListener(_recalculateProgPurchaseBalesModify);
      _farmersDayController.addListener(_recalculateProgFarmersModify);
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
    _farmersDayController.dispose();
    _arrivalsBalesController.dispose();
    _cciPurchaseQtlsController.dispose();
    _cciPurchaseBalesController.dispose();
    _avgKapasRateController.dispose();
    _budgetedLintController.dispose();
    _budgetedShortageController.dispose();
    _cottonSeedRateController.dispose();
    _processingCycleController.dispose();
    _proformaExpensesController.dispose();
    _budgetedPadthaController.dispose();
    _dayPressedBalesController.dispose();
    _marketHighestRateController.dispose();
    _marketLowestRateController.dispose();
    _cciHighestRateController.dispose();
    _cciLowestRateController.dispose();
    _progPressedBalesController.dispose();
    _progPurchaseQtlsController.dispose();
    _progPurchaseBalesController.dispose();
    _progFarmersController.dispose();
    super.dispose();
  }

  // ============================================================
  // RECALCULATION METHODS
  // ============================================================

  void _recalculateProgPressedBales() {
    final dayValue = double.tryParse(_dayPressedBalesController.text) ?? 0;
    _progPressedBalesController.text = _formatNumber(_previousProgPressedBales + dayValue);
  }

  void _recalculateProgPurchaseQtls() {
    final dayValue = double.tryParse(_cciPurchaseQtlsController.text) ?? 0;
    _progPurchaseQtlsController.text = _formatNumber(_previousProgPurchaseQtls + dayValue);
  }

  void _recalculateProgPurchaseBales() {
    final dayValue = double.tryParse(_cciPurchaseBalesController.text) ?? 0;
    _progPurchaseBalesController.text = _formatNumber(_previousProgPurchaseBales + dayValue);
  }

  void _recalculateProgFarmers() {
    final dayValue = double.tryParse(_farmersDayController.text) ?? 0;
    _progFarmersController.text = _formatNumber(_previousProgFarmers + dayValue);
  }

  void _recalculateProgPressedBalesModify() {
    final dayValue = double.tryParse(_dayPressedBalesController.text) ?? 0;
    _progPressedBalesController.text = _formatNumber(_previousProgPressedBales + dayValue);
  }

  void _recalculateProgPurchaseQtlsModify() {
    final dayValue = double.tryParse(_cciPurchaseQtlsController.text) ?? 0;
    _progPurchaseQtlsController.text = _formatNumber(_previousProgPurchaseQtls + dayValue);
  }

  void _recalculateProgPurchaseBalesModify() {
    final dayValue = double.tryParse(_cciPurchaseBalesController.text) ?? 0;
    _progPurchaseBalesController.text = _formatNumber(_previousProgPurchaseBales + dayValue);
  }

  void _recalculateProgFarmersModify() {
    final dayValue = double.tryParse(_farmersDayController.text) ?? 0;
    _progFarmersController.text = _formatNumber(_previousProgFarmers + dayValue);
  }

  // ============================================================
  // ⭐ NEW: FETCH PROGRESSIVE VALUES FOR THE OTHER TWO VARIETIES
  // ============================================================
  Future<void> _fetchOtherVarietiesProgressive() async {
    if (_selectedCentre == null || _selectedCentre!.isEmpty) return;

    try {
      final all = await ApiService.getProgressiveForAllVarieties(
        type: 'purchase',
        centre: _selectedCentre!,
      );

      final others = <String, Map<String, double>>{};
      for (final entry in all.entries) {
        if (entry.key == _selectedVariety) continue; // skip own variety
        others[entry.key] = {
          'progPressedBales': entry.value['progPressedBales'] ?? 0,
          'progPurchaseQtls': entry.value['progPurchaseQtls'] ?? 0,
          'progPurchaseBales': entry.value['progPurchaseBales'] ?? 0,
          'progFarmers': entry.value['progFarmers'] ?? 0,
        };
      }

      if (!mounted) return;
      setState(() {
        _otherVarietiesProgressive = others;
      });

      debugLog('✅ Loaded otherVarietiesProgressive: $others');
    } catch (e) {
      debugLog('❌ Failed to fetch other varieties progressive: $e');
    }
  }

  // ============================================================
  // LOAD EXISTING DATA
  // ============================================================
  void _loadExistingData(Map<String, dynamic> data) {
    final centre = data['centre'] as String?;
    _selectedCentre = (centre != null && centre.isNotEmpty) ? centre : null;
    _reportNoController.text = data['reportNo']?.toString() ?? '';

    if (data['variety'] != null && _varieties.contains(data['variety'])) {
      _selectedVariety = data['variety'];
    }

    _originalPressedBales = double.tryParse(data['dayPressedBales']?.toString() ?? '0') ?? 0;
    _originalPurchaseQtls = double.tryParse(data['cciPurchaseQtls']?.toString() ?? '0') ?? 0;
    _originalPurchaseBales = double.tryParse(data['cciPurchaseBales']?.toString() ?? '0') ?? 0;
    _originalFarmers = double.tryParse(data['farmersDay']?.toString() ?? '0') ?? 0;

    _farmersDayController.text = data['farmersDay']?.toString() ?? '';
    _arrivalsBalesController.text = data['arrivalsBales']?.toString() ?? '';
    _cciPurchaseQtlsController.text = data['cciPurchaseQtls']?.toString() ?? '';
    _cciPurchaseBalesController.text = data['cciPurchaseBales']?.toString() ?? '';
    _avgKapasRateController.text = data['avgKapasRate']?.toString() ?? '';
    _budgetedLintController.text = data['budgetedLint']?.toString() ?? '';
    _budgetedShortageController.text = data['budgetedShortage']?.toString() ?? '';
    _cottonSeedRateController.text = data['cottonSeedRate']?.toString() ?? '';
    _processingCycleController.text = data['processingCycle']?.toString() ?? '';
    _proformaExpensesController.text = data['proformaExpenses']?.toString() ?? '';
    _budgetedPadthaController.text = data['budgetedPadtha']?.toString() ?? '';
    _dayPressedBalesController.text = data['dayPressedBales']?.toString() ?? '';
    _marketHighestRateController.text = data['marketHighestRate']?.toString() ?? '';
    _marketLowestRateController.text = data['marketLowestRate']?.toString() ?? '';
    _cciHighestRateController.text = data['cciHighestRate']?.toString() ?? '';
    _cciLowestRateController.text = data['cciLowestRate']?.toString() ?? '';
    _progPressedBalesController.text = data['progPressedBales']?.toString() ?? '';
    _progPurchaseQtlsController.text = data['progPurchaseQtls']?.toString() ?? '';
    _progPurchaseBalesController.text = data['progPurchaseBales']?.toString() ?? '';
    _progFarmersController.text = data['progFarmers']?.toString() ?? '';

    // Load factories with progressive data
    if (data['factories'] is List && (data['factories'] as List).isNotEmpty) {
      _purchaseFactories = (data['factories'] as List)
          .map((f) => PurchaseFactoryProgData.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList();
    }

    // ⭐ Preserve otherVarietiesProgressive if it already exists on the doc
    final existingOthers = data['otherVarietiesProgressive'];
    if (existingOthers is Map) {
      _otherVarietiesProgressive = {};
      existingOthers.forEach((key, value) {
        if (value is Map) {
          _otherVarietiesProgressive[key.toString()] = {
            'progPressedBales': (value['progPressedBales'] as num?)?.toDouble() ?? 0,
            'progPurchaseQtls': (value['progPurchaseQtls'] as num?)?.toDouble() ?? 0,
            'progPurchaseBales': (value['progPurchaseBales'] as num?)?.toDouble() ?? 0,
            'progFarmers': (value['progFarmers'] as num?)?.toDouble() ?? 0,
          };
        }
      });
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
          _previousProgPressedBales = (response.data!['balesPressedProg'] as num?)?.toDouble() ?? 0;
          _previousProgPurchaseQtls = (response.data!['progPurchaseQtls'] as num?)?.toDouble() ?? 0;
          _previousProgPurchaseBales = (response.data!['progPurchaseBales'] as num?)?.toDouble() ?? 0;
          _previousProgFarmers = (response.data!['farmersProgressive'] as num?)?.toDouble() ?? 0;
          _debugMessage = '✅ Loaded latest progressive values';
        } else {
          _previousProgPressedBales = 0;
          _previousProgPurchaseQtls = 0;
          _previousProgPurchaseBales = 0;
          _previousProgFarmers = 0;
          _debugMessage = '⚠️ No previous entries found, starting from 0';
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalculateProgPressedBalesModify();
        _recalculateProgPurchaseQtlsModify();
        _recalculateProgPurchaseBalesModify();
        _recalculateProgFarmersModify();
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
  // FETCH PREVIOUS PROGRESSIVE - for new entry creation
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
          _previousProgPressedBales = (response.data!['balesPressedProg'] as num?)?.toDouble() ?? 0;
          _previousProgPurchaseQtls = (response.data!['progPurchaseQtls'] as num?)?.toDouble() ?? 0;
          _previousProgPurchaseBales = (response.data!['progPurchaseBales'] as num?)?.toDouble() ?? 0;
          _previousProgFarmers = (response.data!['farmersProgressive'] as num?)?.toDouble() ?? 0;
          _debugMessage = '✅ Loaded progressive values';
        } else {
          _previousProgPressedBales = 0;
          _previousProgPurchaseQtls = 0;
          _previousProgPurchaseBales = 0;
          _previousProgFarmers = 0;
          _debugMessage = '⚠️ No previous values found, starting from 0';
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalculateProgPressedBales();
        _recalculateProgPurchaseQtls();
        _recalculateProgPurchaseBales();
        _recalculateProgFarmers();
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

  // ============================================================
  // UTILITY METHODS
  // ============================================================
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

  Future<void> _autoGenerateReportNo() async {
    if (widget.isModify) return;
    if (_selectedCentre == null || _selectedCentre!.isEmpty) return;

    setState(() {
      _isLoadingReportNo = true;
    });

    final normalizedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final requestedCentre = _selectedCentre;

    try {
      final response = await ApiService.getNextReportNo(
        type: 'purchase',
        centre: _selectedCentre!,
        date: normalizedDate,
      );

      if (!mounted) return;
      if (requestedCentre != _selectedCentre) return;

      final nextReportNo = (response.success && response.data != null)
          ? response.data!['nextReportNo'] as int?
          : null;

      if (nextReportNo != null) {
        setState(() {
          _reportNoController.text = nextReportNo.toString();
        });
      }
    } catch (e) {
      debugLog('❌ Error generating report number: $e');
    } finally {
      if (mounted) setState(() => _isLoadingReportNo = false);
    }
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
      }
      await _autoGenerateReportNo();
    }
  }

  // ============================================================
  // FIND ENTRY
  // ============================================================
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
        _fetchOtherVarietiesProgressive();
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
  // SHOW CELEBRATION
  // ============================================================
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

  // ============================================================
  // BUILD DATA
  // ============================================================
  Map<String, dynamic> _buildPurchaseData() {
    return {
      'reportType': ReportType.dailyPurchase.label,
      'date': _selectedDate.toIso8601String(),
      'variety': _selectedVariety ?? '',
      'centre': _selectedCentre ?? '',
      'reportNo': int.tryParse(_reportNoController.text) ?? 0,
      'farmersDay': double.tryParse(_farmersDayController.text) ?? 0,
      'arrivalsBales': double.tryParse(_arrivalsBalesController.text) ?? 0,
      'cciPurchaseQtls': double.tryParse(_cciPurchaseQtlsController.text) ?? 0,
      'cciPurchaseBales': double.tryParse(_cciPurchaseBalesController.text) ?? 0,
      'avgKapasRate': double.tryParse(_avgKapasRateController.text) ?? 0,
      'budgetedLint': double.tryParse(_budgetedLintController.text) ?? 0,
      'budgetedShortage': double.tryParse(_budgetedShortageController.text) ?? 0,
      'cottonSeedRate': double.tryParse(_cottonSeedRateController.text) ?? 0,
      'processingCycle': int.tryParse(_processingCycleController.text) ?? 0,
      'proformaExpenses': double.tryParse(_proformaExpensesController.text) ?? 0,
      'budgetedPadtha': double.tryParse(_budgetedPadthaController.text) ?? 0,
      'dayPressedBales': double.tryParse(_dayPressedBalesController.text) ?? 0,
      'marketHighestRate': double.tryParse(_marketHighestRateController.text) ?? 0,
      'marketLowestRate': double.tryParse(_marketLowestRateController.text) ?? 0,
      'cciHighestRate': double.tryParse(_cciHighestRateController.text) ?? 0,
      'cciLowestRate': double.tryParse(_cciLowestRateController.text) ?? 0,
      'progPressedBales': double.tryParse(_progPressedBalesController.text) ?? 0,
      'progPurchaseQtls': double.tryParse(_progPurchaseQtlsController.text) ?? 0,
      'progPurchaseBales': double.tryParse(_progPurchaseBalesController.text) ?? 0,
      'progFarmers': double.tryParse(_progFarmersController.text) ?? 0,
      // ⭐ Save the other varieties' progressive values in the document
      'otherVarietiesProgressive': _otherVarietiesProgressive,
      'factories': _purchaseFactories.map((f) => f.toJson()).toList(),
    };
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

    // Make sure otherVarietiesProgressive is up-to-date before saving.
    if (_otherVarietiesProgressive.isEmpty &&
        _selectedCentre != null &&
        _selectedCentre!.isNotEmpty) {
      await _fetchOtherVarietiesProgressive();
    }

    final data = _buildPurchaseData();

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

  // ============================================================
  // FACTORY DIALOG HELPERS
  // ============================================================

  void _openAddPurchaseFactoryDialog() => _showPurchaseFactoryFormDialog(null);
  void _openEditPurchaseFactoryDialog(int index) => _showPurchaseFactoryFormDialog(_purchaseFactories[index]);

  void _showPurchaseFactoryFormDialog(PurchaseFactoryProgData? factoryData) {
    final nameController = TextEditingController(text: factoryData?.factoryName ?? '');
    final progQtlsController = TextEditingController(text: factoryData?.progPurchaseQtls.toString() ?? '');
    final progBalesController = TextEditingController(text: factoryData?.progPurchaseBales.toString() ?? '');

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
                    hint: 'e.g., M/s.Vijay Industries',
                    icon: Icons.factory,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CommonFormWidgets.textField(
                          controller: progQtlsController,
                          label: 'Prog. Purchase (Qtls)',
                          hint: 'e.g., 22708.95',
                          icon: Icons.scale,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CommonFormWidgets.textField(
                          controller: progBalesController,
                          label: 'Prog. Purchase (Bales)',
                          hint: 'e.g., 4268',
                          icon: Icons.inventory,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
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
                final factory = PurchaseFactoryProgData(
                  factoryName: nameController.text,
                  progPurchaseQtls: double.tryParse(progQtlsController.text) ?? 0,
                  progPurchaseBales: double.tryParse(progBalesController.text) ?? 0,
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
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
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
              columnSpacing: 20,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columns: const [
                DataColumn(label: Text('SNO', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Factory Name', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Prog. Pur. (Qtls)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Prog. Pur. (Bales)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _purchaseFactories.asMap().entries.map((entry) {
                final index = entry.key;
                final factory = entry.value;
                return DataRow(cells: [
                  DataCell(Text('${index + 1}')),
                  DataCell(Text(factory.factoryName)),
                  DataCell(Text(factory.progPurchaseQtls.toString())),
                  DataCell(Text(factory.progPurchaseBales.toString())),
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

  // ============================================================
  // BUILD
  // ============================================================

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
        varietyOptions: _varieties,
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

                        // Header Information Section
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
                              _previousProgPressedBales = 0;
                              _previousProgPurchaseQtls = 0;
                              _previousProgPurchaseBales = 0;
                              _previousProgFarmers = 0;
                              _debugMessage = '';
                              _progPressedBalesController.text = '';
                              _progPurchaseQtlsController.text = '';
                              _progPurchaseBalesController.text = '';
                              _progFarmersController.text = '';
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
                                }
                                _fetchOtherVarietiesProgressive();
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

                        // Variety dropdown - only 3 options
                        DropdownButtonFormField<String>(
                          value: _selectedVariety,
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
                          items: _varieties.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedVariety = value;
                              _previousProgPressedBales = 0;
                              _previousProgPurchaseQtls = 0;
                              _previousProgPurchaseBales = 0;
                              _previousProgFarmers = 0;
                              _debugMessage = '';
                              _progPressedBalesController.text = '';
                              _progPurchaseQtlsController.text = '';
                              _progPurchaseBalesController.text = '';
                              _progFarmersController.text = '';
                              _isEntrySaved = false;
                            });
                            if (value != null &&
                                _selectedCentre != null &&
                                _selectedCentre!.isNotEmpty) {
                              if (widget.isModify) {
                                _fetchLatestProgressiveForModify();
                              } else {
                                _fetchPreviousProgressive();
                              }
                              _fetchOtherVarietiesProgressive();
                            }
                          },
                          validator: (value) => value == null ? 'Please select a variety' : null,
                        ),
                        const SizedBox(height: 14),

                        // Purchase Details Section
                        CommonFormWidgets.sectionHeader('Purchase Details'),
                        if (!widget.isModify && _debugMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
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

                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _farmersDayController,
                                label: "Day's Kapas Purchased from No. of Farmers",
                                hint: 'e.g., 69',
                                icon: Icons.people,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _arrivalsBalesController,
                                label: 'Arrivals (In Bales)',
                                hint: 'e.g., 220',
                                icon: Icons.inventory,
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
                                controller: _cciPurchaseQtlsController,
                                label: 'CCI Purchases (In Qtls)',
                                hint: 'e.g., 821.9',
                                icon: Icons.scale,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _cciPurchaseBalesController,
                                label: 'CCI Purchases (In Bales)',
                                hint: 'e.g., 158',
                                icon: Icons.inventory_2,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        CommonFormWidgets.textField(
                          controller: _avgKapasRateController,
                          label: 'Average Kapas rate (In Rs. per qtl)',
                          hint: 'e.g., 7928.68',
                          icon: Icons.currency_rupee,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _budgetedLintController,
                                label: 'Budgeted Lint Percentage (%)',
                                hint: 'e.g., 0.321',
                                icon: Icons.percent,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _budgetedShortageController,
                                label: 'Budgeted Shortage Percentage (%)',
                                hint: 'e.g., 0.027',
                                icon: Icons.warning_amber_rounded,
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
                                controller: _cottonSeedRateController,
                                label: 'Cotton seed rate (In Rs. per qtl)',
                                hint: 'e.g., 3200',
                                icon: Icons.attach_money,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _processingCycleController,
                                label: "Processing cycle (In day's)",
                                hint: 'e.g., 7',
                                icon: Icons.autorenew,
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
                                controller: _proformaExpensesController,
                                label: 'Proforma Expenses (In Rs. per Candy)',
                                hint: 'e.g., 4709.88',
                                icon: Icons.money_off,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _budgetedPadthaController,
                                label: 'Budgeted Padtha (In Rs. per candy)',
                                hint: 'e.g., 69502.94',
                                icon: Icons.receipt,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        CommonFormWidgets.textField(
                          controller: _dayPressedBalesController,
                          label: "Day's pressed bales (In Bales)",
                          hint: 'e.g., 100',
                          icon: Icons.grass,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),

                        // Market & CCI Rates
                        CommonFormWidgets.sectionHeader('Market & CCI Rates'),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Market Rates (In Rs. per qtl)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _marketHighestRateController,
                                label: 'Market Highest',
                                hint: 'e.g., 7000',
                                icon: Icons.arrow_upward,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _marketLowestRateController,
                                label: 'Market Lowest',
                                hint: 'e.g., 6800',
                                icon: Icons.arrow_downward,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            'CCI Rates (In Rs. per qtl)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _cciHighestRateController,
                                label: 'CCI Highest',
                                hint: 'e.g., 8010',
                                icon: Icons.arrow_upward,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _cciLowestRateController,
                                label: 'CCI Lowest',
                                hint: 'e.g., 7689.6',
                                icon: Icons.arrow_downward,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Progressive Values Section
                        CommonFormWidgets.sectionHeader('Progressive Values'),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Auto-calculated from previous entry + today\'s values',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _progPressedBalesController,
                                label: 'Prog. Pressed Bales',
                                hint: _isLoadingPreviousProgressive ? 'Loading...' : 'Auto-calculated',
                                icon: Icons.trending_up,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _progPurchaseQtlsController,
                                label: 'Prog. Purchase (Qtls)',
                                hint: _isLoadingPreviousProgressive ? 'Loading...' : 'Auto-calculated',
                                icon: Icons.trending_up,
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
                                controller: _progPurchaseBalesController,
                                label: 'Prog. Purchase (Bales)',
                                hint: _isLoadingPreviousProgressive ? 'Loading...' : 'Auto-calculated',
                                icon: Icons.trending_up,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CommonFormWidgets.textField(
                                controller: _progFarmersController,
                                label: 'Prog. Kapas Purchased from No. of Farmers',
                                hint: _isLoadingPreviousProgressive ? 'Loading...' : 'Auto-calculated',
                                icon: Icons.trending_up,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Factory Details
                        CommonFormWidgets.sectionHeaderWithAction(
                          'Factory Wise Day Purchase Details',
                          actionLabel: 'Add Factory',
                          onAction: _openAddPurchaseFactoryDialog,
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Enter progressive purchase details for each factory',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
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
                                  backgroundColor: const Color(0xFF0F172A),
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

// ============================================================
// FACTORY DATA MODEL FOR PURCHASE
// ============================================================
class PurchaseFactoryProgData {
  String factoryName;
  double progPurchaseQtls;
  double progPurchaseBales;

  PurchaseFactoryProgData({
    required this.factoryName,
    required this.progPurchaseQtls,
    required this.progPurchaseBales,
  });

  Map<String, dynamic> toJson() => {
    'factoryName': factoryName,
    'progPurchaseQtls': progPurchaseQtls,
    'progPurchaseBales': progPurchaseBales,
  };

  factory PurchaseFactoryProgData.fromJson(Map<String, dynamic> json) => PurchaseFactoryProgData(
    factoryName: json['factoryName'] as String? ?? '',
    progPurchaseQtls: (json['progPurchaseQtls'] as num?)?.toDouble() ?? 0,
    progPurchaseBales: (json['progPurchaseBales'] as num?)?.toDouble() ?? 0,
  );
}