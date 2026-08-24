import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../enums/report_type.dart';
import '../models/report_modals.dart';
import '../screens/find_entry_dialog.dart';
import '../services/apiservice.dart';
import '../widgets/common_form_widgets.dart';

class SeedEntryDialog extends StatefulWidget {
  final bool isModify;
  final Map<String, dynamic>? existingData;

  const SeedEntryDialog({
    super.key,
    this.isModify = false,
    this.existingData,
  });

  @override
  State<SeedEntryDialog> createState() => _SeedEntryDialogState();
}

class _SeedEntryDialogState extends State<SeedEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _lookupFormKey = GlobalKey<FormState>();
  final _factoryFormKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _dialogFocusNode = FocusNode();
  bool _isSubmitting = false;
  DateTime? _lastSubmitTime; // Prevent double submission

  // Find-then-edit flow
  bool _entryFound = false;
  bool _isSearching = false;
  String? _docId;
  String? _lookupError;

  // Header fields
  String? _selectedCentre;
  final _reportNoController = TextEditingController();

  // Variety used only for the Find Entry lookup step — seed reports don't
  // have a single report-level variety (it's per factory row), so this
  // filters for reports containing at least one factory with this variety.
  String? _lookupVariety;

  // Use FactoryData from report_modals.dart (NOT PurchaseFactoryData)
  List<FactoryData> _seedFactories = [];

  DateTime _selectedDate = DateTime.now();
  bool _isLoadingReportNo = false;

  @override
  void initState() {
    super.initState();

    if (widget.isModify && widget.existingData != null) {
      _loadExistingData(widget.existingData!);
      _docId = widget.existingData!['id']?.toString();
      _entryFound = true;
    } else if (!widget.isModify) {
      _entryFound = true;
      _seedFactories = [];

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

  @override
  void dispose() {
    _scrollController.dispose();
    _dialogFocusNode.dispose();
    _reportNoController.dispose();
    super.dispose();
  }

  void _loadExistingData(Map<String, dynamic> data) {
    final centre = data['centre'] as String?;
    _selectedCentre = (centre != null && centre.isNotEmpty) ? centre : null;
    _reportNoController.text = data['reportNo']?.toString() ?? '';

    // Load seed factories - FactoryData from report_modals.dart
    List factoriesData = [];
    if (data['seedFactories'] is List) {
      factoriesData = data['seedFactories'] as List;
    } else if (data['factories'] is List) {
      factoriesData = data['factories'] as List;
    }

    if (factoriesData.isNotEmpty) {
      _seedFactories = factoriesData
          .map((f) => FactoryData.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList();
    }

    if (data['date'] != null) {
      _selectedDate = DateTime.parse(data['date']);
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

  void _resetReportNoToDefault() {
    _reportNoController.text = '1';
  }

  Future<void> _autoGenerateReportNo() async {
    if (widget.isModify) return;
    if (_selectedCentre == null || _selectedCentre!.isEmpty) return;

    setState(() {
      _isLoadingReportNo = true;
      _reportNoController.text = '1';
    });

    final normalizedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final requestedCentre = _selectedCentre;

    try {
      final response = await ApiService.getNextReportNo(
        type: 'seed',
        centre: _selectedCentre!,
        date: normalizedDate,
      );

      if (!mounted) return;
      if (requestedCentre != _selectedCentre) return;

      final nextReportNo = (response.success && response.data != null)
          ? response.data!['nextReportNo'] as int?
          : null;

      setState(() => _reportNoController.text = (nextReportNo ?? 1).toString());
    } catch (e) {
      debugLog('❌ Error generating report number: $e');
      if (mounted && requestedCentre == _selectedCentre) {
        setState(() => _reportNoController.text = '1');
      }
    } finally {
      if (mounted) setState(() => _isLoadingReportNo = false);
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
      type: 'seed',
      centre: _selectedCentre!,
      reportNo: reportNo,
      date: normalizedDate,
      variety: _lookupVariety,
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
      await _autoGenerateReportNo();
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

  void _submitForm() async {
    // Prevent double submission within 2 seconds
    final now = DateTime.now();
    if (_lastSubmitTime != null &&
        now.difference(_lastSubmitTime!).inMilliseconds < 2000) {
      return;
    }
    _lastSubmitTime = now;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Clean up the data before sending it
    final cleanedFactories = _seedFactories.map((f) {
      return FactoryData(
        factoryName: f.factoryName ?? '',
        variety: f.variety ?? '-',
        progressiveRealisable: f.progressiveRealisable ?? 0,
        progressiveSold: f.progressiveSold ?? 0,
        kapasForm: f.kapasForm ?? 0,
        readyForm: f.readyForm ?? 0,
        total: f.total ?? 0,
        baseRate: f.baseRate ?? 0,
        avgProgressiveBudgetedRate: f.avgProgressiveBudgetedRate ?? 0.0,
      );
    }).toList();

    final data = {
      'reportType': ReportType.dailySeed.label,
      'date': _selectedDate.toIso8601String(),
      'centre': _selectedCentre ?? '',
      'reportNo': int.tryParse(_reportNoController.text) ?? 0,
      'seedFactories': cleanedFactories.map((f) => f.toJson()).toList(),
    };

    final ApiResponse response;
    if (widget.isModify && _docId != null) {
      response = await ApiService.updateEntry(_docId!, data);
    } else {
      response = await ApiService.saveSeedEntry(data);
    }

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (response.success) {
      _showCelebration();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
      );
    }
  }

  // -------------------- Factory dialog helpers --------------------

  void _openAddSeedFactoryDialog() => _showSeedFactoryFormDialog(null);
  void _openEditSeedFactoryDialog(int index) => _showSeedFactoryFormDialog(_seedFactories[index]);

  void _showSeedFactoryFormDialog(FactoryData? factoryData) {
    final nameController = TextEditingController(text: factoryData?.factoryName ?? '');
    // Default to a real, valid variety right away — not just for display —
    // so the state variable actually matches what's shown, and sanitize any
    // previously-saved bad value (e.g. '-') that isn't in the current list.
    String selectedVariety = (factoryData?.variety != null &&
        ReportConstants.varieties.contains(factoryData!.variety))
        ? factoryData.variety
        : ReportConstants.varieties.first;
    final realisableController = TextEditingController(text: factoryData?.progressiveRealisable.toString() ?? '');
    final soldController = TextEditingController(text: factoryData?.progressiveSold.toString() ?? '');
    final kapasController = TextEditingController(text: factoryData?.kapasForm.toString() ?? '');
    final readyController = TextEditingController(text: factoryData?.readyForm.toString() ?? '');
    final baseRateController = TextEditingController(text: factoryData?.baseRate.toString() ?? '');
    final avgProgRateController =
    TextEditingController(text: factoryData?.avgProgressiveBudgetedRate.toString() ?? '');

    final isEditing = factoryData != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Factory' : 'Add Factory'),
            content: SizedBox(
              width: 500,
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
                      DropdownButtonFormField<String>(
                        value: selectedVariety,
                        decoration: InputDecoration(
                          labelText: 'Variety',
                          hintText: 'Select variety',
                          prefixIcon: const Icon(Icons.eco, color: Color(0xFF64748B)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: ReportConstants.varieties.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                        onChanged: (value) => setDialogState(() => selectedVariety = value ?? selectedVariety),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please select a variety';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CommonFormWidgets.textField(
                              controller: realisableController,
                              label: 'Progressive Realisable (Total)',
                              hint: 'e.g., 70',
                              icon: Icons.trending_up,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CommonFormWidgets.textField(
                              controller: soldController,
                              label: 'Progressive Sold',
                              hint: 'e.g., 0',
                              icon: Icons.sell,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Day's Unsold Cotton Seed (Quintals)",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: CommonFormWidgets.textField(
                              controller: kapasController,
                              label: 'Kapas Form',
                              hint: 'e.g., 0',
                              icon: Icons.format_align_left,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CommonFormWidgets.textField(
                              controller: readyController,
                              label: 'Ready Form',
                              hint: 'e.g., 70',
                              icon: Icons.check_circle_outline,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Total (auto): ${(int.tryParse(kapasController.text) ?? 0) + (int.tryParse(readyController.text) ?? 0)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CommonFormWidgets.textField(
                              controller: baseRateController,
                              label: "Day's Budgeted Rate",
                              hint: 'e.g., 3700',
                              icon: Icons.currency_rupee,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CommonFormWidgets.textField(
                              controller: avgProgRateController,
                              label: 'Avg. Progressive Budgeted Rate',
                              hint: 'e.g., 3700',
                              icon: Icons.trending_up,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    final progressiveRealisable = int.tryParse(realisableController.text) ?? 0;
                    final progressiveSold = int.tryParse(soldController.text) ?? 0;
                    final kapasForm = int.tryParse(kapasController.text) ?? 0;
                    final readyForm = int.tryParse(readyController.text) ?? 0;
                    final total = kapasForm + readyForm;

                    final factory = FactoryData(
                      factoryName: nameController.text,
                      variety: selectedVariety,
                      progressiveRealisable: progressiveRealisable,
                      progressiveSold: progressiveSold,
                      kapasForm: kapasForm,
                      readyForm: readyForm,
                      total: total,
                      baseRate: int.tryParse(baseRateController.text) ?? 0,
                      avgProgressiveBudgetedRate: double.tryParse(avgProgRateController.text) ?? 0,
                    );

                    setState(() {
                      if (isEditing) {
                        final index = _seedFactories.indexOf(factoryData);
                        _seedFactories[index] = factory;
                      } else {
                        _seedFactories.add(factory);
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
          );
        },
      ),
    );
  }

  void _deleteSeedFactory(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Factory'),
        content: const Text('Are you sure you want to delete this factory?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => _seedFactories.removeAt(index));
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildSeedFactoryTable() {
    if (_seedFactories.isEmpty) {
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

    const borderColor = Color(0xFFE2E8F0);
    const headerBg = Color(0xFFF1F5F9);
    const headerTextStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 10,
      color: Color(0xFF0F172A),
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: IntrinsicColumnWidth(),
              2: IntrinsicColumnWidth(),
              3: IntrinsicColumnWidth(),
              4: IntrinsicColumnWidth(),
              5: FixedColumnWidth(200),
              6: IntrinsicColumnWidth(),
              7: IntrinsicColumnWidth(),
              8: IntrinsicColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder.all(color: borderColor),
            children: [
              // Header Row
              TableRow(
                decoration: BoxDecoration(color: headerBg),
                children: [
                  _buildHeaderCell('S.No.', textAlign: TextAlign.center),
                  _buildHeaderCell('Factory Name', textAlign: TextAlign.center),
                  _buildHeaderCell('Variety', textAlign: TextAlign.center),
                  _buildHeaderCell('Prog Realisable', textAlign: TextAlign.center),
                  _buildHeaderCell('Prog Sold', textAlign: TextAlign.center),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    height: 60,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Day's Unsold",
                          style: headerTextStyle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Divider(color: borderColor, height: 1, thickness: 1),
                        const SizedBox(height: 4),
                        IntrinsicHeight(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: const [
                              Text('Kapas', style: headerTextStyle),
                              VerticalDivider(color: borderColor, width: 1, thickness: 1),
                              Text('Ready', style: headerTextStyle),
                              VerticalDivider(color: borderColor, width: 1, thickness: 1),
                              Text('Total', style: headerTextStyle),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildHeaderCell('Budget Rate', textAlign: TextAlign.center),
                  _buildHeaderCell('Avg Prog Rate', textAlign: TextAlign.center),
                  _buildHeaderCell('', textAlign: TextAlign.center),
                ],
              ),

              // Data Rows
              ..._seedFactories.asMap().entries.map((entry) {
                final index = entry.key;
                final factory = entry.value;
                return TableRow(
                  children: [
                    _buildDataCell('${index + 1}', textAlign: TextAlign.center),
                    _buildDataCell(factory.factoryName, textAlign: TextAlign.center),
                    _buildDataCell(factory.variety ?? '-', textAlign: TextAlign.center),
                    _buildDataCell(factory.progressiveRealisable.toString(), textAlign: TextAlign.center),
                    _buildDataCell(factory.progressiveSold.toString(), textAlign: TextAlign.center),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: IntrinsicHeight(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(factory.kapasForm.toString(), style: const TextStyle(fontSize: 11)),
                            const VerticalDivider(color: borderColor, width: 1, thickness: 1),
                            Text(factory.readyForm.toString(), style: const TextStyle(fontSize: 11)),
                            const VerticalDivider(color: borderColor, width: 1, thickness: 1),
                            Text(factory.total.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    _buildDataCell(factory.baseRate.toString(), textAlign: TextAlign.center),
                    _buildDataCell(factory.avgProgressiveBudgetedRate.toStringAsFixed(0), textAlign: TextAlign.center),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () => _openEditSeedFactoryDialog(index),
                            icon: const Icon(Icons.edit, size: 14, color: Color(0xFFF59E0B)),
                            tooltip: 'Edit',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => _deleteSeedFactory(index),
                            icon: const Icon(Icons.delete, size: 14, color: Colors.red),
                            tooltip: 'Delete',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {TextAlign textAlign = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: textAlign,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 10,
          color: Color(0xFF0F172A),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDataCell(String text, {TextAlign textAlign = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: textAlign,
        style: const TextStyle(fontSize: 11),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  // -------------------- Build --------------------

  @override
  Widget build(BuildContext context) {
    if (widget.isModify && !_entryFound) {
      return FindEntryDialog(
        entryTypeLabel: 'Seed',
        headerIcon: Icons.eco_rounded,
        headerColor: const Color(0xFFD1FAE5),
        formKey: _lookupFormKey,
        focusNode: _dialogFocusNode,
        selectedCentre: _selectedCentre,
        onCentreChanged: (v) => setState(() => _selectedCentre = v),
        selectedVariety: _lookupVariety,
        varietyOptions: ReportConstants.varieties,
        onVarietyChanged: (v) => setState(() => _lookupVariety = v),
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
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(
          maxWidth: 950,
          maxHeight: 750,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fixed Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.eco_rounded, color: Color(0xFF0F172A), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$title Seed Report',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    CommonFormWidgets.closeButton(context),
                  ],
                ),
                const SizedBox(height: 12),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Form(
                      key: _formKey,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 100,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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

                              Row(
                                children: [
                                  Expanded(
                                    child: CommonFormWidgets.centreDropdown(
                                      selectedCentre: _selectedCentre,
                                      readOnly: widget.isModify,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedCentre = value;
                                          _resetReportNoToDefault();
                                        });
                                        if (value != null) _autoGenerateReportNo();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: CommonFormWidgets.textField(
                                      controller: _reportNoController,
                                      label: 'Report No.',
                                      hint: _isLoadingReportNo ? 'Generating...' : 'e.g., 1',
                                      icon: Icons.numbers,
                                      keyboardType: TextInputType.number,
                                      readOnly: widget.isModify || _isLoadingReportNo,
                                      suffixIcon: _isLoadingReportNo
                                          ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
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
                                  ),
                                ],
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
                                          'Date: ${CommonFormWidgets.formatDate(_selectedDate)}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              CommonFormWidgets.sectionHeaderWithAction(
                                'Ginning & Pressing Factory Details',
                                actionLabel: 'Add Factory',
                                onAction: _openAddSeedFactoryDialog,
                              ),
                              const SizedBox(height: 12),
                              _buildSeedFactoryTable(),
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
              ],
            );
          },
        ),
      ),
    );
  }
}