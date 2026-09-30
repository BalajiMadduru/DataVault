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
  final _pmNoController = TextEditingController();
  final _prNoController = TextEditingController();
  final _lotNoController = TextEditingController();
  final _sampleBaleNoController = TextEditingController();
  final _godownController = TextEditingController();
  final _noOfBalesController = TextEditingController(text: '100');
  final _moistureController = TextEditingController(text: '8.1');
  final _pressingFactoryController = TextEditingController();
  final _pmarkNoController = TextEditingController();

  final List<String> _varieties = ['BB MOD', 'BB SPL MOD', 'MECH'];
  String? _selectedVariety;

  DateTime _selectedDate = DateTime.now();
  bool _isLoadingReportNo = false;

  // Bale data
  List<WeightBaleEntry> _baleEntries = [];
  static const int defaultBaleCount = 100;

  // Summary controllers (per-bale figures, all user editable)
  final _totalGrossController = TextEditingController();
  final _tareWeightController = TextEditingController(text: '1.30');
  final _totalNettController = TextEditingController();

  // Guards
  bool _isSyncingSummary = false;

  /// Which of Gross / Nett the user typed last. Tare changes recalculate
  /// the OTHER field, so the value the user typed is never overwritten.
  _SummarySource _lastEdited = _SummarySource.gross;

  /// Bumped after generate / load so the bale text fields rebuild.
  /// Not bumped while typing, so focus is kept.
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
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadDefaultCentre();
        if (_selectedCentre != null && _selectedCentre!.isNotEmpty) {
          await _autoGenerateReportNo();
        }
      });
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
    _pmNoController.dispose();
    _prNoController.dispose();
    _lotNoController.dispose();
    _sampleBaleNoController.dispose();
    _godownController.dispose();
    _noOfBalesController.dispose();
    _moistureController.dispose();
    _pressingFactoryController.dispose();
    _pmarkNoController.dispose();
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

  /// User typed Gross  -> Nett  = Gross - Tare
  void _onGrossChanged(String _) {
    if (_isSyncingSummary) return;
    _lastEdited = _SummarySource.gross;
    _recalcNett();
  }

  /// User typed Nett   -> Gross = Nett + Tare
  void _onNettChanged(String _) {
    if (_isSyncingSummary) return;
    _lastEdited = _SummarySource.nett;
    _recalcGross();
  }

  /// User typed Tare   -> recalc whichever field was NOT typed last
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
    // Gross drives the bale colouring / generator, so refresh the UI
    if (mounted) setState(() {});
  }

  /// No. of bales changed → rebuild grid (keeps existing values)
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
  // UNIQUE WHOLE-NUMBER GENERATOR
  //
  //  * Gross (user input) = the maximum a bale can weigh
  //  * Tare  (user input)
  //  * Nett  = Gross - Tare
  //  * Every bale gets a WHOLE number (no decimals)
  //  * Every bale is <= Gross
  //  * No value is repeated across the bale cells
  // ============================================================

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

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

    // Highest allowed value = gross (whole number, never above it)
    final hi = gross.floor();

    // Need `count` different whole numbers between 1 and hi
    if (hi < count) {
      _showError(
          'Gross weight ${_fmt(gross)} is too low to give $count unique '
              'whole-number bale weights. Increase the gross weight.');
      return;
    }

    // Window just below gross, a bit larger than needed so it looks random
    final windowSize = min(hi, max(count, (count * 1.25).ceil()));
    final lo = hi - windowSize + 1;

    final values = List<int>.generate(windowSize, (i) => lo + i)
      ..shuffle(Random());
    final picked = values.take(count).toList();

    setState(() {
      for (int i = 0; i < count; i++) {
        _baleEntries[i] =
            _baleEntries[i].copyWith(weight: picked[i].toDouble());
      }
      _gridVersion++; // refresh the text fields
    });
  }

  /// Weights (> 0) that appear in more than one cell.
  Set<int> get _duplicateWeights {
    final seen = <int>{};
    final dup = <int>{};
    for (final e in _baleEntries) {
      final w = e.weight.round();
      if (w <= 0) continue;
      if (!seen.add(w)) dup.add(w);
    }
    return dup;
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

  // ============================================================
  // DATA LOADING
  // ============================================================

  void _loadExistingData(Map<String, dynamic> data) {
    final centre = data['centre'] as String?;
    _selectedCentre = (centre != null && centre.isNotEmpty) ? centre : null;
    _reportNoController.text = data['reportNo']?.toString() ?? '';
    _pmNoController.text = data['pmNo']?.toString() ?? '';
    _prNoController.text = data['prNo']?.toString() ?? '';
    _lotNoController.text = data['lotNo']?.toString() ?? '';
    _sampleBaleNoController.text = data['sampleBaleNo']?.toString() ?? '';
    _godownController.text = data['godown']?.toString() ?? '';
    _noOfBalesController.text =
        data['noOfBales']?.toString() ?? defaultBaleCount.toString();
    _moistureController.text = data['moisture']?.toString() ?? '';
    _pressingFactoryController.text =
        data['pressingFactory']?.toString() ?? '';
    _pmarkNoController.text = data['pmarkNo']?.toString() ?? '';

    final tare = (data['tareWeight'] as num?)?.toDouble() ?? 1.30;
    _setSynced(() => _tareWeightController.text = _fmt(tare));

    if (data['variety'] != null && _varieties.contains(data['variety'])) {
      _selectedVariety = data['variety'];
    }

    if (data['baleEntries'] is List) {
      final entries = data['baleEntries'] as List;
      _baleEntries = entries
          .map((e) =>
          WeightBaleEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final targetCount =
          int.tryParse(_noOfBalesController.text) ?? defaultBaleCount;
      if (_baleEntries.length < targetCount) {
        for (int i = _baleEntries.length; i < targetCount; i++) {
          _baleEntries.add(WeightBaleEntry(baleNo: i + 1, weight: 0));
        }
      }
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

  Future<void> _autoGenerateReportNo() async {
    if (widget.isModify) return;
    if (_selectedCentre == null || _selectedCentre!.isEmpty) return;

    setState(() => _isLoadingReportNo = true);
    final normalizedDate =
    DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final requestedCentre = _selectedCentre;

    try {
      final response = await ApiService.getNextWeightListReportNo(
        centre: _selectedCentre!,
        date: normalizedDate,
      );

      if (!mounted) return;
      if (requestedCentre != _selectedCentre) return;

      final nextReportNo = (response.success && response.data != null)
          ? response.data!['nextReportNo'] as int?
          : null;

      if (nextReportNo != null) {
        setState(() => _reportNoController.text = nextReportNo.toString());
      }
    } catch (e) {
      debugPrint('❌ Error generating report number: $e');
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
            colorScheme:
            const ColorScheme.light(primary: Color(0xFF0F172A)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _autoGenerateReportNo();
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
  // SUBMIT
  // ============================================================

  Future<bool> _checkEntryExists() async {
    if (widget.isModify) return false;
    final reportNo = int.tryParse(_reportNoController.text) ?? 0;
    if (reportNo == 0) return false;

    final normalizedDate =
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

    if (_summaryGross > 0 && _baleEntries.any((e) => e.weight > _summaryGross)) {
      _showError('Some bale weights are above the Gross weight '
          '(${_fmt(_summaryGross)}). Click "Generate Bale Weights" again '
          'or correct the red values.');
      return;
    }

    if (_duplicateWeights.isNotEmpty) {
      _showError('Repeated bale weights found (${_duplicateWeights.join(', ')}). '
          'Every bale must have a different whole-number weight.');
      return;
    }

    _lastSubmitTime = now;
    setState(() => _isSubmitting = true);

    final data = {
      'reportType': 'WeightList',
      'date': _selectedDate.toIso8601String(),
      'centre': _selectedCentre ?? '',
      'reportNo': int.tryParse(_reportNoController.text) ?? 0,
      'variety': _selectedVariety ?? '',
      'pmNo': _pmNoController.text.trim(),
      'prNo': _prNoController.text.trim(),
      'lotNo': _lotNoController.text.trim(),
      'sampleBaleNo': _sampleBaleNoController.text.trim(),
      'godown': _godownController.text.trim(),
      'noOfBales': _currentBaleCount,
      'moisture': double.tryParse(_moistureController.text) ?? 0,
      'pressingFactory': _pressingFactoryController.text.trim(),
      'pmarkNo': _pmarkNoController.text.trim(),
      'tareWeight': _currentTare,
      'totalGrossWeight': _summaryGross,
      'totalNettWeight': _summaryNett,
      'baleEntries': _baleEntries.map((e) => e.toJson()).toList(),
    };

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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF94A3B8)),
      ),
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                for (int c = 0; c < cols; c++) ...[
                  _headerCell('NO'),
                  _headerCell('Kgs.'),
                ],
              ],
            ),
          ),
          for (int r = 0; r < rows; r++)
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  for (int c = 0; c < cols; c++) ...[
                    _dataCell(() {
                      final idx = startIndex + r + (c * rows);
                      return idx < _baleEntries.length ? '${idx + 1}' : '';
                    }()),
                    _buildWeightCell(startIndex + r + (c * rows)),
                  ],
                ],
              ),
            ),
          Container(
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
                  _totalCell(c == 0 ? 'TOTAL' : ''),
                  _totalCell(_fmt(
                      _getColumnTotal(startIndex + (c * rows), rows))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _getColumnTotal(int startBaleNo, int count) {
    double total = 0;
    for (int i = 0; i < count; i++) {
      final baleNo = startBaleNo + i + 1;
      final index = baleNo - 1;
      if (index >= 0 && index < _baleEntries.length) {
        total += _baleEntries[index].weight;
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
      return Expanded(child: Container());
    }
    final entry = _baleEntries[baleIndex];
    final isDuplicate = entry.weight > 0 &&
        _duplicateWeights.contains(entry.weight.round());
    final isAboveGross = _summaryGross > 0 && entry.weight > _summaryGross;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: TextFormField(
          // Key only changes on generate/load, NOT while typing → keeps focus
          key: ValueKey('bale_${entry.baleNo}_$_gridVersion'),
          initialValue: entry.weight == 0 ? '' : _fmt(entry.weight),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: (isDuplicate || isAboveGross) ? Colors.red : null,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding:
            EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            border: InputBorder.none,
          ),
          onChanged: (value) {
            final w = (int.tryParse(value) ?? 0).toDouble();
            setState(() {
              _baleEntries[baleIndex] =
                  _baleEntries[baleIndex].copyWith(weight: w);
            });
          },
        ),
      ),
    );
  }

  // ============================================================
  // BUILD — HEADER (matches Excel)
  // ============================================================

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text('THE COTTON CORPORATION OF INDIA LTD',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          const Text('BRANCH OFFICE :: MAHABUBNAGAR',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155))),
          const SizedBox(height: 2),
          Text('CENTRE :: ${(_selectedCentre ?? '').toUpperCase()}',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _compactField(
                controller: _pmarkNoController,
                label: 'P.MARK NO',
                hint: 'e.g., VI TMC',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _compactField(
                controller: _prNoController,
                label: 'P.R.NO',
                hint: 'e.g., 1001-1100',
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedVariety,
                decoration: _compactInputDecoration('VARIETY', 'Select'),
                items: _varieties
                    .map((v) =>
                    DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedVariety = v),
                validator: (v) => v == null ? 'Select variety' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _compactField(
                controller: _sampleBaleNoController,
                label: 'Sample Bale No',
                hint: 'e.g., 38,75',
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _compactField(
                controller: _lotNoController,
                label: 'LOT NO',
                hint: 'e.g., 1001',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _compactField(
                controller: _godownController,
                label: 'GODOWN',
                hint: 'e.g., Elements Godown, Medchal',
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _compactField(
                controller: _noOfBalesController,
                label: 'NO OF BALES',
                hint: 'e.g., 100',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _compactField(
                controller: _moistureController,
                label: 'MOISTURE',
                hint: 'e.g., 8.1',
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          InkWell(
            onTap: widget.isModify ? null : () => _selectDate(context),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(6),
                color:
                widget.isModify ? const Color(0xFFF1F5F9) : Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    'DATE OF PRESSING: ${CommonFormWidgets.formatDate(_selectedDate)}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155)),
                  ),
                  const Spacer(),
                  if (!widget.isModify)
                    const Icon(Icons.arrow_drop_down,
                        color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _compactField(
            controller: _pressingFactoryController,
            label: 'NAME OF THE PRESSING FACTORY',
            hint: 'e.g., VIJAY INDUSTRIES',
            isUpperCase: true,
          ),
        ],
      ),
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
            label: 'Total Gross Weight :',
            controller: _totalGrossController,
            hint: 'e.g. 175',
            onChanged: _onGrossChanged,
          ),
          const SizedBox(height: 6),
          _editableSummaryRow(
            label: 'Tare Weight :',
            controller: _tareWeightController,
            hint: '1.30',
            width: 80,
            onChanged: _onTareChanged,
          ),
          const SizedBox(height: 6),
          _editableSummaryRow(
            label: 'Total Nett Weight :',
            controller: _totalNettController,
            hint: 'Gross - Tare',
            highlight: true,
            onChanged: _onNettChanged,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Sum of bales: ${_fmt(_baleEntries.fold<double>(0, (a, e) => a + e.weight))}'
                  '   |   Average: ${_fmt(_baleEntries.isEmpty ? 0 : _baleEntries.fold<double>(0, (a, e) => a + e.weight) / _baleEntries.length)}',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B)),
            ),
          ),
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
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: CommonFormWidgets.centreDropdown(
                            selectedCentre: _selectedCentre,
                            readOnly: false,
                            onChanged: (value) {
                              setState(() {
                                _selectedCentre = value;
                                _reportNoController.text = '';
                              });
                              if (value != null) {
                                _rememberCentre(value);
                                _autoGenerateReportNo();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: CommonFormWidgets.textField(
                            controller: _reportNoController,
                            label: 'Report No.',
                            hint: _isLoadingReportNo
                                ? 'Loading...'
                                : 'e.g., 1',
                            icon: Icons.numbers,
                            keyboardType: TextInputType.number,
                            readOnly: true,
                          ),
                        ),
                      ],
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

                          CommonFormWidgets.sectionHeader(
                              'Weight Summary (per bale)'),
                          const SizedBox(height: 8),
                          _buildSummarySection(),
                          const SizedBox(height: 16),

                          CommonFormWidgets.sectionHeader(
                              'Bale Weights (In Kgs.)'),
                          const SizedBox(height: 8),

                          // Blocks of 50 bales (10 rows x 5 cols), like the sheet
                          for (int b = 0; b < (totalBales / 50).ceil(); b++)
                            _buildBaleTableSection(
                              startIndex: b * 50,
                              rows: ((totalBales - b * 50).clamp(1, 50) / 5)
                                  .ceil(),
                              cols: 5,
                            ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
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
                              valueColor:
                              AlwaysStoppedAnimation<Color>(
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