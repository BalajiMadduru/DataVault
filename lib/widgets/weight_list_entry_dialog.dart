// File: lib/dialogs/weight_list_entry_dialog.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../enums/report_type.dart';
import '../models/report_modals.dart';
import '../screens/find_entry_dialog.dart';
import '../services/apiservice.dart';
import '../widgets/common_form_widgets.dart';
import 'preview_dialog.dart';

class WeightListEntryDialog extends StatefulWidget {
  final bool isModify;
  final Map<String, dynamic>? existingData;

  const WeightListEntryDialog({
    super.key,
    this.isModify = false,
    this.existingData,
  });

  @override
  State<WeightListEntryDialog> createState() => _WeightListEntryDialogState();
}

class _WeightListEntryDialogState extends State<WeightListEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _lookupFormKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _dialogFocusNode = FocusNode();

  bool _isSubmitting = false;
  DateTime? _lastSubmitTime;
  bool _entryFound = false;
  bool _isSearching = false;
  String? _docId;
  String? _lookupError;

  // Header fields
  String? _selectedCentre;
  final _reportNoController = TextEditingController();
  final _prNoController = TextEditingController();
  final _lotNoController = TextEditingController();
  final _sampleBaleNoController = TextEditingController();
  final _ubinNoController = TextEditingController();
  final _noOfBalesController = TextEditingController(text: '100');
  final _moistureController = TextEditingController(text: '8.1');
  final _pressingFactoryController = TextEditingController();

  /// DT.OF PRESSING — now a free-text field ("100 BALES: 7-12-2025").
  final _pressingDateController = TextEditingController();

  // ---- Dropdown (DD) fields from the Excel format -------------------------
  final List<String> _varieties = ['BB MOD', 'BB SPL MOD', 'MECH'];
  final List<String> _pmNos = ['SCGF'];
  final List<String> _cropYears = ['2025-26', '2026-27'];
  final List<String> _godowns = ['SRISAI WAREHOUSE,HYDERABADROAD,RAICHUR'];

  String? _selectedVariety;
  String? _selectedPmNo;
  String? _selectedCropYear = '2026-27';
  String? _selectedGodown;

  /// Kept for lookup (Find Entry dialog still queries by date).
  DateTime _selectedDate = DateTime.now();

  // Bale data
  List<WeightBaleEntry> _baleEntries = [];
  static const int defaultBaleCount = 100;

  // Summary controllers
  final _totalGrossController = TextEditingController();
  final _tareWeightController = TextEditingController(text: '1.2');
  final _totalNettController = TextEditingController();

  bool _isSyncingSummary = false;
  _SummarySource _lastEdited = _SummarySource.gross;
  int _gridVersion = 0;

  @override
  void initState() {
    super.initState();
    _initializeBaleEntries();
    _noOfBalesController.addListener(_onBaleCountChanged);

    if (widget.isModify && widget.existingData != null) {
      _loadExistingData(widget.existingData!);
      _docId = widget.existingData!['id']?.toString();
      _entryFound = true;
    } else if (!widget.isModify) {
      _entryFound = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDefaultCentre());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_dialogFocusNode);
    });
  }

  void _initializeBaleEntries() {
    final count = int.tryParse(_noOfBalesController.text) ?? defaultBaleCount;
    _baleEntries = List.generate(
      count,
          (index) => WeightBaleEntry(baleNo: index + 1, weight: 0),
    );
  }

  @override
  void dispose() {
    _noOfBalesController.removeListener(_onBaleCountChanged);
    _scrollController.dispose();
    _dialogFocusNode.dispose();
    _reportNoController.dispose();
    _prNoController.dispose();
    _ubinNoController.dispose();
    _lotNoController.dispose();
    _sampleBaleNoController.dispose();
    _noOfBalesController.dispose();
    _moistureController.dispose();
    _pressingFactoryController.dispose();
    _pressingDateController.dispose();
    _totalGrossController.dispose();
    _tareWeightController.dispose();
    _totalNettController.dispose();
    super.dispose();
  }

  // ============================================================
  // SUMMARY LISTENERS
  // ============================================================

  void _setSynced(VoidCallback fn) {
    _isSyncingSummary = true;
    try {
      fn();
    } finally {
      _isSyncingSummary = false;
    }
  }

  void _onGrossChanged(String _) {
    if (_isSyncingSummary) return;
    _lastEdited = _SummarySource.gross;
    _recalcNett();
  }

  void _onNettChanged(String _) {
    if (_isSyncingSummary) return;
    _lastEdited = _SummarySource.nett;
    _recalcGross();
  }

  void _onTareChanged(String _) {
    if (_isSyncingSummary) return;
    if (_lastEdited == _SummarySource.nett) {
      _recalcGross();
    } else {
      _recalcNett();
    }
  }

  void _recalcNett() {
    final gross = double.tryParse(_totalGrossController.text) ?? 0;
    final tare = double.tryParse(_tareWeightController.text) ?? 0;
    _setSynced(() {
      _totalNettController.text = gross <= 0 ? '' : _fmt(gross - tare);
    });
  }

  void _recalcGross() {
    final nett = double.tryParse(_totalNettController.text) ?? 0;
    final tare = double.tryParse(_tareWeightController.text) ?? 0;
    _setSynced(() {
      _totalGrossController.text = nett <= 0 ? '' : _fmt(nett + tare);
    });
    if (mounted) setState(() {});
  }

  void _onBaleCountChanged() {
    final count = int.tryParse(_noOfBalesController.text) ?? 0;
    if (count <= 0 || count > 1000) return;
    if (count == _baleEntries.length) return;

    setState(() {
      final old = _baleEntries;
      _baleEntries = List.generate(
        count,
            (i) => WeightBaleEntry(
          baleNo: i + 1,
          weight: i < old.length ? old[i].weight : 0,
        ),
      );
      _gridVersion++;
    });
  }

  // ============================================================
  // BALE WEIGHT GENERATOR
  // ============================================================

  static const int _wideWindowFrom = 165;

  List<int> _spreadFor(int gross) {
    if (gross >= _wideWindowFrom) return [4, 5];
    return [2, 2];
  }

  int get _minAllowed {
    final g = _summaryGross.floor();
    return max(1, g - _spreadFor(g)[0]);
  }

  int get _maxAllowed {
    final g = _summaryGross.floor();
    return g + _spreadFor(g)[1];
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  int _targetTotal(double gross, int count) => (gross * count).round();

  void _generateBaleWeights() {
    final gross = double.tryParse(_totalGrossController.text) ?? 0;
    final count = _baleEntries.length;

    if (gross <= 0) {
      _showError('Enter Gross weight first');
      return;
    }
    if (count <= 0) {
      _showError('Enter No. of bales first');
      return;
    }

    final lo = _minAllowed;
    final hi = _maxAllowed;
    final targetTotal = _targetTotal(gross, count);

    if (targetTotal < lo * count || targetTotal > hi * count) {
      _showError('Cannot reach this gross within $lo - $hi per bale');
      return;
    }

    final rng = Random();
    final base = targetTotal ~/ count;
    final remainder = targetTotal - base * count;
    final weights = List<int>.filled(count, base);
    final idxs = List<int>.generate(count, (i) => i)..shuffle(rng);
    for (int k = 0; k < remainder; k++) {
      weights[idxs[k]] += 1;
    }

    for (int n = 0; n < count * 20; n++) {
      final a = rng.nextInt(count);
      final b = rng.nextInt(count);
      if (a == b) continue;
      if (weights[a] < hi && weights[b] > lo) {
        weights[a] += 1;
        weights[b] -= 1;
      }
    }

    setState(() {
      for (int i = 0; i < count; i++) {
        _baleEntries[i] =
            _baleEntries[i].copyWith(weight: weights[i].toDouble());
      }
      _gridVersion++;
    });
  }

  // ============================================================
  // MODIFY MODE: BALE EDITS -> GROSS / NETT
  // ============================================================

  void _syncSummaryFromBales() {
    final filled = _baleEntries.where((e) => e.weight > 0).toList();
    if (filled.isEmpty) return;

    final avg =
        filled.fold<double>(0, (a, e) => a + e.weight) / filled.length;
    final gross = double.parse(avg.toStringAsFixed(2));

    _lastEdited = _SummarySource.gross;
    _setSynced(() {
      _totalGrossController.text = _fmt(gross);
    });
    _recalcNett();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  double get _currentTare => double.tryParse(_tareWeightController.text) ?? 0;
  double get _summaryGross => double.tryParse(_totalGrossController.text) ?? 0;
  double get _summaryNett => double.tryParse(_totalNettController.text) ?? 0;

  int get _currentBaleCount =>
      int.tryParse(_noOfBalesController.text) ?? _baleEntries.length;

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  /// Parses the pressing date out of a free-text field like
  /// "100 BALES: 7-12-2025". Returns null when it can't find a date.
  DateTime? _parsePressingDate(String text) {
    // Try common patterns: d-m-yyyy, dd-mm-yyyy, d/m/yyyy, dd/mm/yyyy
    final match = RegExp(r'(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})')
        .firstMatch(text);
    if (match != null) {
      final d = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      var y = int.parse(match.group(3)!);
      if (y < 100) y += 2000;
      try {
        return DateTime(y, m, d);
      } catch (_) {
        return null;
      }
    }
    // Fallback: ISO parse
    return DateTime.tryParse(text);
  }

  // ============================================================
  // DATA LOADING
  // ============================================================

  String? _pickOption(List<String> options, dynamic value) {
    final v = value?.toString().trim() ?? '';
    if (v.isEmpty) return null;
    if (!options.contains(v)) options.add(v);
    return v;
  }

  void _loadExistingData(Map<String, dynamic> data) {
    final centre = data['centre'] as String?;
    _selectedCentre = (centre != null && centre.isNotEmpty) ? centre : null;
    _reportNoController.text = data['reportNo']?.toString() ?? '';
    _selectedPmNo = _pickOption(_pmNos, data['pmNo']);
    _prNoController.text = data['prNo']?.toString() ?? '';
    _lotNoController.text = data['lotNo']?.toString() ?? '';
    _sampleBaleNoController.text = data['sampleBaleNo']?.toString() ?? '';
    _selectedGodown = _pickOption(_godowns, data['godown']);
    _selectedCropYear =
        _pickOption(_cropYears, data['cropYear']) ?? _selectedCropYear;
    _ubinNoController.text = data['ubinNo']?.toString() ?? '';
    _noOfBalesController.text =
        data['noOfBales']?.toString() ?? defaultBaleCount.toString();
    _moistureController.text = data['moisture']?.toString() ?? '';
    _pressingFactoryController.text =
        data['pressingFactory']?.toString() ?? '';

    // Prefer the free-text pressing date if the server stored one.
    final storedPressingDate = data['pressingDate']?.toString();
    if (storedPressingDate != null && storedPressingDate.isNotEmpty) {
      _pressingDateController.text = storedPressingDate;
    } else if (data['date'] != null) {
      // Fall back to constructing "<n> BALES: d-m-yyyy" from the DateTime.
      try {
        final dt = DateTime.parse(data['date']);
        final n = (data['noOfBales'] ?? defaultBaleCount).toString();
        _pressingDateController.text =
        '$n BALES: ${dt.day}-${dt.month}-${dt.year}';
      } catch (_) {}
    }

    final tare = (data['tareWeight'] as num?)?.toDouble() ?? 1.30;
    _setSynced(() => _tareWeightController.text = _fmt(tare));

    _selectedVariety = _pickOption(_varieties, data['variety']);

    if (data['baleEntries'] is List) {
      final entries = data['baleEntries'] as List;
      final loaded = entries
          .map((e) =>
          WeightBaleEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => a.baleNo.compareTo(b.baleNo));

      final targetCount =
          int.tryParse(_noOfBalesController.text) ?? defaultBaleCount;

      _baleEntries = List.generate(targetCount, (i) {
        if (i < loaded.length) return loaded[i];
        return WeightBaleEntry(baleNo: i + 1, weight: 0);
      });
    }

    if (data['date'] != null) {
      try {
        _selectedDate = DateTime.parse(data['date']);
      } catch (_) {}
    }

    _gridVersion++;
    _lastEdited = _SummarySource.gross;
    final g = (data['totalGrossWeight'] as num?)?.toDouble();
    final n = (data['totalNettWeight'] as num?)?.toDouble();
    _setSynced(() {
      _totalGrossController.text = g != null ? _fmt(g) : '';
      _totalNettController.text = n != null ? _fmt(n) : '';
    });
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

  /// Used by the Find Entry dialog (lookup by date).
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
            const ColorScheme.light(primary: Color(0xFF0F172A)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
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

    final normalizedDate =
    DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    final response = await ApiService.findWeightListEntry(
      centre: _selectedCentre!,
      reportNo: reportNo,
      date: normalizedDate,
    );

    if (!mounted) return;

    if (response.success && response.data != null) {
      final entry =
      Map<String, dynamic>.from(response.data!['entry'] as Map);
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

  // ============================================================
  // PREVIEW
  // ============================================================

  Map<String, dynamic> _buildPayload() {
    // If the user typed a date, use that for the stored `date` too,
    // otherwise fall back to _selectedDate.
    final typedDate = _parsePressingDate(_pressingDateController.text);
    return {
      'reportType': 'WeightList',
      'date': (typedDate ?? _selectedDate).toIso8601String(),
      'pressingDate': _pressingDateController.text.trim(),
      'centre': _selectedCentre ?? '',
      'reportNo': int.tryParse(_reportNoController.text) ?? 0,
      'variety': _selectedVariety ?? '',
      'lotNo': _lotNoController.text.trim(),
      'prNo': _prNoController.text.trim(),
      'pmNo': _selectedPmNo ?? '',
      'noOfBales': _currentBaleCount,
      'cropYear': _selectedCropYear ?? '',
      'sampleBaleNo': _sampleBaleNoController.text.trim(),
      'ubinNo': _ubinNoController.text.trim(),
      'moisture': double.tryParse(_moistureController.text) ?? 0,
      'godown': _selectedGodown ?? '',
      'pressingFactory': _pressingFactoryController.text.trim(),
      'tareWeight': _currentTare,
      'totalGrossWeight': _summaryGross,
      'totalNettWeight': _summaryNett,
      'baleEntries': _baleEntries.map((e) => e.toJson()).toList(),
    };
  }

  void _showPreview() {
    final previewData = _buildPayload();

    showDialog(
      context: context,
      builder: (_) => PreviewDialog(
        type: ReportType.weightList,
        data: previewData,
      ),
    );
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<bool> _checkEntryExists() async {
    if (widget.isModify) return false;
    final reportNo = int.tryParse(_reportNoController.text) ?? 0;
    if (reportNo == 0) return false;

    final typedDate = _parsePressingDate(_pressingDateController.text);
    final normalizedDate = typedDate ??
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    try {
      final response = await ApiService.checkWeightListEntryExists(
        centre: _selectedCentre!,
        reportNo: reportNo,
        date: normalizedDate,
      );
      return response.success && response.data != null
          ? response.data!['exists'] == true
          : false;
    } catch (e) {
      return false;
    }
  }

  void _submitForm() async {
    final now = DateTime.now();
    if (_lastSubmitTime != null &&
        now.difference(_lastSubmitTime!).inMilliseconds < 2000) return;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_baleEntries.every((e) => e.weight == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please generate or enter bale weights'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!widget.isModify &&
        _summaryGross > 0 &&
        _baleEntries.any((e) =>
        e.weight > 0 &&
            (e.weight < _minAllowed || e.weight > _maxAllowed))) {
      _showError('Some bale weights are outside the allowed range '
          '$_minAllowed - $_maxAllowed for Gross ${_fmt(_summaryGross)}. '
          'Click "Generate Bale Weights" again or correct the red values.');
      return;
    }

    _lastSubmitTime = now;
    setState(() => _isSubmitting = true);

    final data = _buildPayload();

    final ApiResponse response;
    if (widget.isModify && _docId != null) {
      response = await ApiService.updateWeightListEntry(_docId!, data);
    } else {
      final exists = await _checkEntryExists();
      if (exists) {
        setState(() => _isSubmitting = false);
        _showDuplicateErrorDialog();
        return;
      }
      response = await ApiService.saveWeightListEntry(data);
    }

    if (!mounted) return;

    if (!response.success) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = false);
    _showCelebration();
  }

  void _showDuplicateErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade700, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('Duplicate Entry',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A))),
          ],
        ),
        content: const Text(
          'A weight list with the same Centre, Report No., and Date already exists.',
          style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCelebration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                  color: Color(0xFFD1FAE5), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF059669), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isModify
                  ? 'Weight List Updated!'
                  : 'Weight List Created!',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text('Redirecting to dashboard...',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFF0F172A))),
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
  // BUILD — BALE GRID
  // ============================================================

  Widget _buildBaleTableSection({
    required int startIndex,
    required int rows,
    required int cols,
  }) {
    const double cellHeight = 30;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF94A3B8)),
      ),
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF1F5F9),
            height: 28,
            child: Row(
              children: [
                for (int c = 0; c < cols; c++) ...[
                  _headerCell('S.L.NO'),
                  _headerCell('KGS'),
                ],
              ],
            ),
          ),

          for (int r = 0; r < rows; r++)
            Container(
              height: cellHeight,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  for (int c = 0; c < cols; c++) ...[
                    _dataCell(() {
                      final idx = startIndex + (c * rows) + r;
                      return idx < _baleEntries.length ? '${idx + 1}' : '';
                    }()),
                    _buildWeightCell(startIndex + (c * rows) + r),
                  ],
                ],
              ),
            ),

          Container(
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(color: Color(0xFF94A3B8), width: 1.5),
                bottom: BorderSide(color: Color(0xFF94A3B8), width: 1.5),
              ),
            ),
            child: Row(
              children: [
                for (int c = 0; c < cols; c++) ...[
                  _totalCell(c == 0 ? 'TOTAL ::' : ''),
                  _totalCell(_fmt(
                    _getColumnTotal(startIndex + (c * rows), rows),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _getColumnTotal(int startBaleIndex, int rows) {
    double total = 0;
    for (int r = 0; r < rows; r++) {
      final idx = startBaleIndex + r;
      if (idx >= 0 && idx < _baleEntries.length) {
        total += _baleEntries[idx].weight;
      }
    }
    return total;
  }

  Widget _headerCell(String text) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      alignment: Alignment.center,
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A))),
    ),
  );

  Widget _dataCell(String text) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      alignment: Alignment.center,
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF334155))),
    ),
  );

  Widget _totalCell(String text) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      alignment: Alignment.center,
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A))),
    ),
  );

  Widget _buildWeightCell(int baleIndex) {
    if (baleIndex >= _baleEntries.length) {
      return Expanded(
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
            ),
          ),
        ),
      );
    }
    final entry = _baleEntries[baleIndex];
    final isOutOfRange = !widget.isModify &&
        _summaryGross > 0 &&
        entry.weight > 0 &&
        (entry.weight < _minAllowed || entry.weight > _maxAllowed);

    return Expanded(
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
          ),
        ),
        alignment: Alignment.center,
        child: TextFormField(
          key: ValueKey('bale_${entry.baleNo}_$_gridVersion'),
          initialValue: entry.weight == 0 ? '' : _fmt(entry.weight),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isOutOfRange ? Colors.red : const Color(0xFF0F172A),
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (value) {
            final w = (int.tryParse(value) ?? 0).toDouble();
            setState(() {
              _baleEntries[baleIndex] =
                  _baleEntries[baleIndex].copyWith(weight: w);
              if (widget.isModify) _syncSummaryFromBales();
            });
          },
        ),
      ),
    );
  }

  // ============================================================
  // BUILD — HEADER
  // ============================================================

  Widget _buildHeaderSection() {
    const titleStyle = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A));
    const subStyle = TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text('THE COTTON CORPORATION OF INDIA LTD.',
              style: titleStyle),
          const SizedBox(height: 2),
          Text('CENTRE ::: ${(_selectedCentre ?? '').toUpperCase()}',
              style: titleStyle),
          const SizedBox(height: 2),
          const Text('F.P.BALES WEIGHT LIST AT THE TIME OF PRESSING',
              style: subStyle),
          const SizedBox(height: 10),

          // VARIETY (DD)            |  LOT NO
          Row(children: [
            Expanded(
              child: _dropdownField(
                label: 'VARIETY (DD)',
                value: _selectedVariety,
                options: _varieties,
                onChanged: (v) => setState(() => _selectedVariety = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _compactField(
                controller: _lotNoController,
                label: 'LOT NO',
                hint: 'e.g., 1031',
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // DT.OF PRESSING (free text)  |  P.R.NO
          Row(children: [
            Expanded(
              child: _compactField(
                controller: _pressingDateController,
                label: 'DT.OF PRESSING',
                hint: 'e.g., 100 BALES: 7-12-2025',
                isUpperCase: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _compactField(
                controller: _prNoController,
                label: 'P.R.NO',
                hint: 'e.g., 12101-12200',
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // P.M.NO (DD)             |  NO OF BALES
          Row(children: [
            Expanded(
              child: _dropdownField(
                label: 'P.M.NO (DD)',
                value: _selectedPmNo,
                options: _pmNos,
                onChanged: (v) => setState(() => _selectedPmNo = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _compactField(
                controller: _noOfBalesController,
                label: 'NO OF BALES',
                hint: 'e.g., 100',
                keyboardType: TextInputType.number,
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // CROP YEAR (DD)          |  S.B.NO
          Row(children: [
            Expanded(
              child: _dropdownField(
                label: 'CROP YEAR (DD)',
                value: _selectedCropYear,
                options: _cropYears,
                onChanged: (v) => setState(() => _selectedCropYear = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _compactField(
                controller: _sampleBaleNoController,
                label: 'S.B.NO',
                hint: 'e.g., 35/61',
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // UBIN NO                 |  LOT AVG MOISTURE
          Row(children: [
            Expanded(
              child: _compactField(
                controller: _ubinNoController,
                label: 'UBIN NO',
                hint: 'e.g., 25096HUB00005101-00005200',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _compactField(
                controller: _moistureController,
                label: 'LOT AVG MOISTURE',
                hint: 'e.g., 8.6',
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // NAME OF THE GODOWN (DD)
          _dropdownField(
            label: 'NAME OF THE GODOWN (DD)',
            value: _selectedGodown,
            options: _godowns,
            onChanged: (v) => setState(() => _selectedGodown = v),
          ),
          const SizedBox(height: 8),

          // FACTORY NAME :::
          _compactField(
            controller: _pressingFactoryController,
            label: 'FACTORY NAME',
            hint: 'e.g., M/s. SANDEEP COTTON GINNING FACTORY',
          ),
        ],
      ),
    );
  }

  /// Dropdown used for the "(DD)" fields of the sheet.
  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: _compactInputDecoration(label, 'Select'),
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0F172A)),
      items: options
          .map((o) => DropdownMenuItem(
          value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => (v == null || v.isEmpty) ? 'Select $label' : null,
    );
  }

  Widget _compactField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    bool readOnly = false,
    bool isUpperCase = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      textCapitalization: isUpperCase
          ? TextCapitalization.characters
          : TextCapitalization.none,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: readOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
      ),
      decoration: _compactInputDecoration(label, hint),
      onChanged: isUpperCase
          ? (value) {
        final upper = value.toUpperCase();
        if (value != upper) {
          controller.value = TextEditingValue(
            text: upper,
            selection: TextSelection.collapsed(offset: upper.length),
          );
        }
      }
          : null,
    );
  }

  InputDecoration _compactInputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B)),
      hintStyle: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
      isDense: true,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide:
          const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  // ============================================================
  // BUILD — SUMMARY
  // ============================================================

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _editableSummaryRow(
            label: 'TOTAL GROSS WT ::',
            controller: _totalGrossController,
            hint: 'e.g. 175',
            onChanged: _onGrossChanged,
          ),
          const SizedBox(height: 6),
          _editableSummaryRow(
            label: 'TOTAL TARE WT ::',
            controller: _tareWeightController,
            hint: '1.2',
            width: 80,
            onChanged: _onTareChanged,
          ),
          const SizedBox(height: 6),
          _editableSummaryRow(
            label: 'TOTAL NET WT ::',
            controller: _totalNettController,
            hint: 'Gross - Tare',
            highlight: true,
            onChanged: _onNettChanged,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Sum of bales: ${_targetTotal(_summaryGross, _baleEntries.length)}',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B)),
            ),
          ),
          if (!widget.isModify) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _generateBaleWeights,
                icon: const Icon(Icons.auto_awesome,
                    size: 16, color: Colors.white),
                label: const Text('Generate Bale Weights',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _editableSummaryRow({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool highlight = false,
    bool readOnly = false,
    double width = 120,
    ValueChanged<String>? onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155)),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: width,
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            onChanged: onChanged,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlight ? const Color(0xFF0F172A) : null,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
              const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              isDense: true,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(
                      color: Color(0xFF0F172A), width: 1.2)),
              fillColor: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
              filled: true,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD — FOOTER (matches Excel bottom block)
  //
  //              For The Cotton Corporation of India Ltd.
  //  Factory Owner / Rep              Centre Incharge
  // ============================================================

  Widget _buildFooterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'For The Cotton Corporation of India Ltd.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Factory Owner / Rep',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Centre Incharge',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (widget.isModify && !_entryFound) {
      return FindEntryDialog(
        entryTypeLabel: 'Weight List',
        headerIcon: Icons.scale_rounded,
        headerColor: const Color(0xFFFEF3C7),
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

    final title = widget.isModify ? 'Modify' : 'Create';
    final totalBales = _baleEntries.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Focus(
        focusNode: _dialogFocusNode,
        autofocus: true,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.of(context).pop(),
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxWidth: 1200,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.scale_rounded,
                            color: Color(0xFF0F172A), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('$title Weight List',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A))),
                      ),
                      if (widget.isModify)
                        TextButton.icon(
                          onPressed: _isSubmitting ? null : _resetLookup,
                          icon: const Icon(Icons.search, size: 16),
                          label: const Text('Change entry'),
                          style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A)),
                        ),
                      CommonFormWidgets.closeButton(context),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (!widget.isModify)
                    CommonFormWidgets.centreDropdown(
                      selectedCentre: _selectedCentre,
                      readOnly: false,
                      onChanged: (value) {
                        setState(() => _selectedCentre = value);
                        if (value != null) _rememberCentre(value);
                      },
                    ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CommonFormWidgets.sectionHeader(
                              'Header Information'),
                          const SizedBox(height: 8),
                          _buildHeaderSection(),
                          const SizedBox(height: 16),

                          // ---- BALE GRID (Excel: rows 13-37) ----
                          CommonFormWidgets.sectionHeader(
                              'Bale Weights (In Kgs.)'),
                          const SizedBox(height: 8),
                          for (int b = 0;
                          b < (totalBales / 50).ceil();
                          b++)
                            _buildBaleTableSection(
                              startIndex: b * 50,
                              rows: ((totalBales - b * 50).clamp(1, 50) / 5)
                                  .ceil(),
                              cols: 5,
                            ),
                          const SizedBox(height: 16),

                          // ---- SUMMARY (Excel: rows 39-41) ----
                          CommonFormWidgets.sectionHeader(
                              'Weight Summary (per bale)'),
                          const SizedBox(height: 8),
                          _buildSummarySection(),
                          const SizedBox(height: 16),

                          // ---- FOOTER / SIGNATURES (Excel bottom) ----
                          _buildFooterSection(),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _showPreview,
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('Preview'),
                          style: OutlinedButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
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
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                              : Text(
                            widget.isModify ? 'Update' : 'Submit',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
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
    );
  }
}

enum _SummarySource { gross, nett }

// ============================================================
// DATA MODEL
// ============================================================

class WeightBaleEntry {
  final int baleNo;
  final double weight;

  WeightBaleEntry({required this.baleNo, required this.weight});

  WeightBaleEntry copyWith({int? baleNo, double? weight}) {
    return WeightBaleEntry(
      baleNo: baleNo ?? this.baleNo,
      weight: weight ?? this.weight,
    );
  }

  Map<String, dynamic> toJson() => {
    'baleNo': baleNo,
    'weight': weight,
  };

  factory WeightBaleEntry.fromJson(Map<String, dynamic> json) {
    return WeightBaleEntry(
      baleNo: (json['baleNo'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
    );
  }
}