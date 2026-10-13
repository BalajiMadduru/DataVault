import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../enums/report_type.dart';
import '../models/report_modals.dart';
import '../screens/find_entry_dialog.dart';
import '../services/apiservice.dart';
import '../widgets/common_form_widgets.dart';

class HeapEntryDialog extends StatefulWidget {
  final bool isModify;
  final Map<String, dynamic>? existingData;

  const HeapEntryDialog({
    super.key,
    this.isModify = false,
    this.existingData,
  });

  @override
  State<HeapEntryDialog> createState() => _HeapEntryDialogState();
}

class _HeapEntryDialogState extends State<HeapEntryDialog> {
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
  final _heapNoController = TextEditingController();

  // Date range
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();

  // Factory dropdown
  static const List<String> _factoryNames = [
    'Vijay Industries',
    'Balaji Industries',
  ];
  String? _selectedFactory;

  // Crop year dropdown
  final List<String> _cropYears = ['2025-26', '2026-27'];
  String? _selectedCropYear = '2025-26';

  // Variety dropdown
  final List<String> _varieties = ['BB MOD', 'BB SPL MOD', 'MECH'];
  String? _selectedVariety;

  @override
  void initState() {
    super.initState();

    if (widget.isModify && widget.existingData != null) {
      _loadExistingData(widget.existingData!);
      _docId = widget.existingData!['id']?.toString();
      _entryFound = true;
    } else if (!widget.isModify) {
      _entryFound = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadDefaultCentre();
        await _autoGenerateReportNo();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_dialogFocusNode);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _dialogFocusNode.dispose();
    _reportNoController.dispose();
    _heapNoController.dispose();
    super.dispose();
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

    try {
      final response = await ApiService.getNextHeapReportNo(
        centre: _selectedCentre!,
      );

      if (!mounted) return;

      if (response.success && response.data != null) {
        final nextReportNo = response.data!['nextReportNo'] as int?;
        if (nextReportNo != null) {
          setState(() {
            _reportNoController.text = nextReportNo.toString();
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error generating report number: $e');
    }
  }

  void _loadExistingData(Map<String, dynamic> data) {
    _selectedCentre = data['centre']?.toString();
    _reportNoController.text = data['reportNo']?.toString() ?? '';
    _heapNoController.text = data['heapNo']?.toString() ?? '';
    _selectedFactory = data['factoryName']?.toString();
    _selectedCropYear = data['cropYear']?.toString();
    _selectedVariety = data['variety']?.toString();

    if (data['fromDate'] != null) {
      try {
        _fromDate = DateTime.parse(data['fromDate']);
      } catch (_) {}
    }
    if (data['toDate'] != null) {
      try {
        _toDate = DateTime.parse(data['toDate']);
      } catch (_) {}
    }
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
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
    if (picked != null && picked != _fromDate) {
      setState(() => _fromDate = picked);
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
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
    if (picked != null && picked != _toDate) {
      setState(() => _toDate = picked);
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

    final response = await ApiService.findHeapEntry(
      centre: _selectedCentre!,
      reportNo: reportNo,
    );

    if (!mounted) return;

    if (response.success && response.data != null) {
      final entry = Map<String, dynamic>.from(response.data!['entry'] as Map);
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
              decoration: const BoxDecoration(
                  color: Color(0xFFD1FAE5), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF059669), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isModify
                  ? 'Heap Report Updated!'
                  : 'Heap Report Created!',
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

  void _submitForm() async {
    final now = DateTime.now();
    if (_lastSubmitTime != null &&
        now.difference(_lastSubmitTime!).inMilliseconds < 2000) {
      return;
    }
    _lastSubmitTime = now;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final data = {
      'reportType': 'Heap',
      'centre': _selectedCentre ?? '',
      'reportNo': int.tryParse(_reportNoController.text) ?? 0,
      'factoryName': _selectedFactory ?? '',
      'cropYear': _selectedCropYear ?? '',
      'fromDate': _fromDate.toIso8601String(),
      'toDate': _toDate.toIso8601String(),
      'heapNo': _heapNoController.text.trim(),
      'variety': _selectedVariety ?? '',
    };

    final ApiResponse response;
    if (widget.isModify && _docId != null) {
      response = await ApiService.updateHeapEntry(_docId!, data);
    } else {
      response = await ApiService.saveHeapEntry(data);
    }

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (response.success) {
      _showCelebration();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3)),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isModify && !_entryFound) {
      return FindEntryDialog(
        entryTypeLabel: 'Heap',
        headerIcon: Icons.inventory_2_rounded,
        headerColor: const Color(0xFFFEF3C7),
        formKey: _lookupFormKey,
        focusNode: _dialogFocusNode,
        selectedCentre: _selectedCentre,
        onCentreChanged: (v) => setState(() => _selectedCentre = v),
        selectedVariety: null,
        varietyOptions: const [],
        onVarietyChanged: null,
        reportNoController: _reportNoController,
        selectedDate: DateTime.now(),
        onDateTap: () {},
        lookupError: _lookupError,
        isSearching: _isSearching,
        onFind: _findEntry,
      );
    }

    final title = widget.isModify ? 'Modify' : 'Create';

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
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                        child: const Icon(Icons.inventory_2_rounded,
                            color: Color(0xFF0F172A), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$title Heap Report',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (widget.isModify)
                        TextButton.icon(
                          onPressed: _isSubmitting ? null : _resetLookup,
                          icon: const Icon(Icons.search, size: 16),
                          label: const Text('Change'),
                          style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A)),
                        ),
                      CommonFormWidgets.closeButton(context),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Centre dropdown
                          CommonFormWidgets.centreDropdown(
                            selectedCentre: _selectedCentre,
                            readOnly: widget.isModify,
                            onChanged: (value) {
                              setState(() => _selectedCentre = value);
                              if (value != null) {
                                _rememberCentre(value);
                                _autoGenerateReportNo();
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          // Factory dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedFactory,
                            decoration: InputDecoration(
                              labelText: 'Name of the Factory',
                              hintText: 'Select factory',
                              prefixIcon: const Icon(Icons.factory,
                                  color: Color(0xFF64748B)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF0F172A), width: 2),
                              ),
                            ),
                            items: _factoryNames
                                .map((f) => DropdownMenuItem(
                                value: f, child: Text(f)))
                                .toList(),
                            onChanged: widget.isModify
                                ? null
                                : (value) =>
                                setState(() => _selectedFactory = value),
                            validator: (value) =>
                            (value == null || value.isEmpty)
                                ? 'Please select a factory'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Crop Year dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedCropYear,
                            decoration: InputDecoration(
                              labelText: 'Crop Year',
                              hintText: 'Select crop year',
                              prefixIcon: const Icon(Icons.calendar_month,
                                  color: Color(0xFF64748B)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF0F172A), width: 2),
                              ),
                            ),
                            items: _cropYears
                                .map((y) => DropdownMenuItem(
                                value: y, child: Text(y)))
                                .toList(),
                            onChanged: widget.isModify
                                ? null
                                : (value) =>
                                setState(() => _selectedCropYear = value),
                            validator: (value) =>
                            (value == null || value.isEmpty)
                                ? 'Please select a crop year'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Variety dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedVariety,
                            decoration: InputDecoration(
                              labelText: 'Variety',
                              hintText: 'Select variety',
                              prefixIcon: const Icon(Icons.eco,
                                  color: Color(0xFF64748B)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF0F172A), width: 2),
                              ),
                            ),
                            items: _varieties
                                .map((v) => DropdownMenuItem(
                                value: v, child: Text(v)))
                                .toList(),
                            onChanged: widget.isModify
                                ? null
                                : (value) =>
                                setState(() => _selectedVariety = value),
                            validator: (value) =>
                            (value == null || value.isEmpty)
                                ? 'Please select a variety'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Purchase Details Date Range
                          const Text(
                            'Purchase Details Date Range',
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
                                child: InkWell(
                                  onTap: widget.isModify
                                      ? null
                                      : () => _selectFromDate(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(12),
                                      color: widget.isModify
                                          ? const Color(0xFFF1F5F9)
                                          : Colors.white,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today,
                                            size: 18,
                                            color: Color(0xFF64748B)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _formatDate(_fromDate),
                                            style: const TextStyle(
                                                fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('to',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: widget.isModify
                                      ? null
                                      : () => _selectToDate(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(12),
                                      color: widget.isModify
                                          ? const Color(0xFFF1F5F9)
                                          : Colors.white,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today,
                                            size: 18,
                                            color: Color(0xFF64748B)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _formatDate(_toDate),
                                            style: const TextStyle(
                                                fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Heap No
                          CommonFormWidgets.textField(
                            controller: _heapNoController,
                            label: 'Heap No',
                            hint: 'Enter heap number',
                            icon: Icons.numbers,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter heap number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Report No (auto-generated)
                          CommonFormWidgets.textField(
                            controller: _reportNoController,
                            label: 'Report No',
                            hint: 'Auto-generated',
                            icon: Icons.description,
                            keyboardType: TextInputType.number,
                            readOnly: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                            height: 20,
                            width: 20,
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
    );
  }
}