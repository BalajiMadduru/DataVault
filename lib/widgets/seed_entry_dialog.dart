import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../enums/report_type.dart';
import '../models/report_modals.dart';
import '../screens/find_entry_dialog.dart';
import '../services/apiservice.dart';
import '../widgets/common_form_widgets.dart';
import 'preview_dialog.dart';

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

class SeedFactoryRow {
  String factoryName;
  String variety;
  double realisable;
  double realised;
  double soldQty;
  double progDelivery;
  double marketRateMin;
  double marketRateMax;

  SeedFactoryRow({
    required this.factoryName,
    required this.variety,
    required this.realisable,
    required this.realised,
    required this.soldQty,
    required this.progDelivery,
    required this.marketRateMin,
    required this.marketRateMax,
  });

  double get ready1 {
    if (realised < soldQty) return 0;
    return realised - soldQty;
  }

  double get kaps1 => realisable - soldQty - ready1;
  double get total1 => kaps1 + ready1;

  double get kaps2 {
    if (realised > soldQty) return 0;
    return soldQty - realised;
  }

  double get ready2 => soldQty - progDelivery - kaps2;
  double get total2 => kaps2 + ready2;

  Map<String, dynamic> toJson() => {
    'factoryName': factoryName,
    'variety': variety,
    'realisable': realisable,
    'realised': realised,
    'soldQty': soldQty,
    'progDelivery': progDelivery,
    'marketRateMin': marketRateMin,
    'marketRateMax': marketRateMax,
  };

  factory SeedFactoryRow.fromJson(Map<String, dynamic> json) => SeedFactoryRow(
    factoryName: json['factoryName'] as String? ?? '',
    variety: json['variety'] as String? ?? '',
    realisable: (json['realisable'] as num?)?.toDouble() ??
        (json['progressiveRealisable'] as num?)?.toDouble() ??
        0,
    realised: (json['realised'] as num?)?.toDouble() ??
        (json['progressiveSold'] as num?)?.toDouble() ??
        0,
    soldQty: (json['soldQty'] as num?)?.toDouble() ?? 0,
    progDelivery: (json['progDelivery'] as num?)?.toDouble() ?? 0,
    marketRateMin: (json['marketRateMin'] as num?)?.toDouble() ?? 0,
    marketRateMax: (json['marketRateMax'] as num?)?.toDouble() ?? 0,
  );
}

class _SeedEntryDialogState extends State<SeedEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _lookupFormKey = GlobalKey<FormState>();
  final _factoryFormKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _factoryTableScrollController = ScrollController();
  final FocusNode _dialogFocusNode = FocusNode();
  bool _isSubmitting = false;
  DateTime? _lastSubmitTime;

  bool _entryFound = false;
  bool _isSearching = false;
  String? _docId;
  String? _lookupError;

  String? _selectedCentre;
  final _reportNoController = TextEditingController();

  String? _lookupVariety;

  // ⭐ NEW: Factory names for the dropdown
  static const List<String> _factoryNames = [
    'Vijay Industries',
    'Balaji Industries',
  ];

  List<SeedFactoryRow> _seedFactories = [];

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
    _factoryTableScrollController.dispose();
    _dialogFocusNode.dispose();
    _reportNoController.dispose();
    super.dispose();
  }

  void _loadExistingData(Map<String, dynamic> data) {
    final centre = data['centre'] as String?;
    _selectedCentre = (centre != null && centre.isNotEmpty) ? centre : null;
    _reportNoController.text = data['reportNo']?.toString() ?? '';

    List factoriesData = [];
    if (data['seedFactories'] is List) {
      factoriesData = data['seedFactories'] as List;
    } else if (data['factories'] is List) {
      factoriesData = data['factories'] as List;
    }

    if (factoriesData.isNotEmpty) {
      _seedFactories = factoriesData
          .map((f) =>
          SeedFactoryRow.fromJson(Map<String, dynamic>.from(f as Map)))
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

    final normalizedDate =
    DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
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

      setState(
              () => _reportNoController.text = (nextReportNo ?? 1).toString());
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

    final normalizedDate =
    DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

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

  void _showPreview() {
    final previewData = {
      'reportType': ReportType.dailySeed.label,
      'date': _selectedDate.toIso8601String(),
      'centre': _selectedCentre ?? '',
      'reportNo': int.tryParse(_reportNoController.text) ?? 0,
      'seedFactories': _seedFactories.map((f) => f.toJson()).toList(),
    };

    showDialog(
      context: context,
      builder: (_) => PreviewDialog(
        type: ReportType.dailySeed,
        data: previewData,
      ),
    );
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
                  ? 'Report Updated Successfully!'
                  : 'Report Created Successfully!',
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
      'reportType': ReportType.dailySeed.label,
      'date': _selectedDate.toIso8601String(),
      'centre': _selectedCentre ?? '',
      'reportNo': int.tryParse(_reportNoController.text) ?? 0,
      'seedFactories': _seedFactories.map((f) => f.toJson()).toList(),
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
        SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3)),
      );
    }
  }

  void _openAddSeedFactoryDialog() => _showSeedFactoryFormDialog(null);
  void _openEditSeedFactoryDialog(int index) =>
      _showSeedFactoryFormDialog(_seedFactories[index]);

  // ⭐ CHANGED: Factory dropdown
  void _showSeedFactoryFormDialog(SeedFactoryRow? factoryData) {
    // Ensure any legacy factory name from old data is available in the list
    final legacyName = factoryData?.factoryName.trim() ?? '';
    final factoryOptions = List<String>.from(_factoryNames);
    if (legacyName.isNotEmpty && !factoryOptions.contains(legacyName)) {
      factoryOptions.add(legacyName);
    }

    String? selectedFactory =
    legacyName.isEmpty ? null : legacyName;

    String selectedVariety = (factoryData?.variety != null &&
        ReportConstants.varieties.contains(factoryData!.variety))
        ? factoryData.variety
        : ReportConstants.varieties.first;

    final realisableController =
    TextEditingController(text: factoryData?.realisable.toString() ?? '');
    final realisedController =
    TextEditingController(text: factoryData?.realised.toString() ?? '');
    final soldQtyController =
    TextEditingController(text: factoryData?.soldQty.toString() ?? '');
    final progDeliveryController = TextEditingController(
        text: factoryData?.progDelivery.toString() ?? '');
    final marketRateMinController = TextEditingController(
        text: factoryData?.marketRateMin.toString() ?? '');
    final marketRateMaxController = TextEditingController(
        text: factoryData?.marketRateMax.toString() ?? '');

    final kaps1Controller = TextEditingController();
    final ready1Controller = TextEditingController();
    final total1Controller = TextEditingController();
    final kaps2Controller = TextEditingController();
    final ready2Controller = TextEditingController();
    final total2Controller = TextEditingController();

    final isEditing = factoryData != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double d(TextEditingController c) =>
              double.tryParse(c.text.trim()) ?? 0;

          String fmt(double v) => v == v.roundToDouble()
              ? v.toInt().toString()
              : v.toStringAsFixed(2);

          void recompute() {
            final realisable = d(realisableController);
            final realised = d(realisedController);
            final soldQty = d(soldQtyController);
            final progDelivery = d(progDeliveryController);

            final ready1 = realised < soldQty ? 0.0 : realised - soldQty;
            final kaps1 = realisable - soldQty - ready1;
            final total1 = kaps1 + ready1;

            final kaps2 = realised > soldQty ? 0.0 : soldQty - realised;
            final ready2 = soldQty - progDelivery - kaps2;
            final total2 = kaps2 + ready2;

            kaps1Controller.text = fmt(kaps1);
            ready1Controller.text = fmt(ready1);
            total1Controller.text = fmt(total1);
            kaps2Controller.text = fmt(kaps2);
            ready2Controller.text = fmt(ready2);
            total2Controller.text = fmt(total2);
          }

          if (kaps1Controller.text.isEmpty &&
              realisableController.text.isNotEmpty) {
            recompute();
          }

          return AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isEditing ? 'Edit Factory' : 'Add Factory'),
            content: SizedBox(
              width: 700,
              child: Form(
                key: _factoryFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isEditing)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CommonFormWidgets.textField(
                            controller: TextEditingController(
                              text: (_seedFactories.indexOf(factoryData) + 1)
                                  .toString(),
                            ),
                            label: 'Sno',
                            hint: '',
                            icon: Icons.numbers,
                            readOnly: true,
                          ),
                        ),

                      // ⭐ FACTORY DROPDOWN
                      DropdownButtonFormField<String>(
                        value: selectedFactory,
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
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        items: factoryOptions
                            .map((v) => DropdownMenuItem(
                            value: v, child: Text(v)))
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => selectedFactory = value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a factory';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: selectedVariety,
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
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        items: ReportConstants.varieties
                            .map((v) =>
                            DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (value) => setDialogState(
                                () => selectedVariety = value ?? selectedVariety),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a variety';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'PROG. QTY. OF COTTON SEED (IN QTLS)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      TextFormField(
                        controller: realisableController,
                        keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setDialogState(recompute),
                        decoration: InputDecoration(
                          labelText: 'Realisable',
                          hintText: 'e.g., 14832.36',
                          prefixIcon: const Icon(Icons.trending_up,
                              color: Color(0xFF64748B)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF0F172A), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: realisedController,
                        keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setDialogState(recompute),
                        decoration: InputDecoration(
                          labelText: 'Realised',
                          hintText: 'e.g., 14832.36',
                          prefixIcon: const Icon(Icons.check_circle_outline,
                              color: Color(0xFF64748B)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF0F172A), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: soldQtyController,
                        keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setDialogState(recompute),
                        decoration: InputDecoration(
                          labelText: 'Sold Quantity',
                          hintText: 'e.g., 14832.36',
                          prefixIcon: const Icon(Icons.sell,
                              color: Color(0xFF64748B)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF0F172A), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'PROGRESSIVE DELIVERY (IN QTLS)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      TextFormField(
                        controller: progDeliveryController,
                        keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setDialogState(recompute),
                        decoration: InputDecoration(
                          labelText: 'UNSOLD QTY (IN QTLS)',
                          hintText: 'e.g., 14800',
                          prefixIcon:
                          const Icon(Icons.local_shipping_outlined,
                              color: Color(0xFF64748B)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF0F172A), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: CommonFormWidgets.textField(
                              controller: kaps1Controller,
                              label: 'Kaps',
                              hint: 'auto',
                              icon: Icons.inventory_2_outlined,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CommonFormWidgets.textField(
                              controller: ready1Controller,
                              label: 'Ready',
                              hint: 'auto',
                              icon: Icons.check_outlined,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CommonFormWidgets.textField(
                              controller: total1Controller,
                              label: 'Total',
                              hint: 'auto',
                              icon: Icons.summarize_outlined,
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'SOLD BUT NOT LIFTED QTY (IN QTLS)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Expanded(
                            child: CommonFormWidgets.textField(
                              controller: kaps2Controller,
                              label: 'Kaps',
                              hint: 'auto',
                              icon: Icons.inventory_2_outlined,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CommonFormWidgets.textField(
                              controller: ready2Controller,
                              label: 'Ready',
                              hint: 'auto',
                              icon: Icons.check_outlined,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CommonFormWidgets.textField(
                              controller: total2Controller,
                              label: 'Total',
                              hint: 'auto',
                              icon: Icons.summarize_outlined,
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'COTTON SEED MARKET RATE (In Rs.)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Expanded(
                            child: CommonFormWidgets.textField(
                              controller: marketRateMinController,
                              label: 'Minimum',
                              hint: 'e.g., 3150',
                              icon: Icons.arrow_downward,
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CommonFormWidgets.textField(
                              controller: marketRateMaxController,
                              label: 'Maximum',
                              hint: 'e.g., 3200',
                              icon: Icons.arrow_upward,
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Kaps / Ready / Total are auto-calculated from the input fields above.',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF94A3B8)),
                        ),
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
                    final row = SeedFactoryRow(
                      factoryName: selectedFactory ?? '',
                      variety: selectedVariety,
                      realisable:
                      double.tryParse(realisableController.text) ?? 0,
                      realised: double.tryParse(realisedController.text) ?? 0,
                      soldQty: double.tryParse(soldQtyController.text) ?? 0,
                      progDelivery:
                      double.tryParse(progDeliveryController.text) ?? 0,
                      marketRateMin:
                      double.tryParse(marketRateMinController.text) ?? 0,
                      marketRateMax:
                      double.tryParse(marketRateMaxController.text) ?? 0,
                    );

                    setState(() {
                      if (isEditing) {
                        final index = _seedFactories.indexOf(factoryData!);
                        _seedFactories[index] = row;
                      } else {
                        _seedFactories.add(row);
                      }
                    });

                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEditing
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF059669),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
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
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
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
              Text('No factories added yet',
                  style: TextStyle(color: Color(0xFF64748B))),
              Text('Click "Add Factory" to add one',
                  style:
                  TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ],
          ),
        ),
      );
    }

    String fmt(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

    const borderColor = Color(0xFFE2E8F0);
    const headerBg = Color(0xFFF1F5F9);

    Widget headerCell(String text, {int flex = 2}) => Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 10,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    );

    Widget dataCell(String text, {int flex = 2, bool bold = false}) => Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Scrollbar(
          controller: _factoryTableScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _factoryTableScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1650,
              child: Column(
                children: [
                  Container(
                    color: headerBg,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            alignment: Alignment.center,
                            child: const Text('SR.\nNO.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            alignment: Alignment.center,
                            child: const Text('CENTRE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            alignment: Alignment.center,
                            child: const Text('NAME OF THE\nFACTORY',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            alignment: Alignment.center,
                            child: const Text('VARIETY',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            color: const Color(0xFFE2E8F0),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            alignment: Alignment.center,
                            child: const Text(
                                'PROG. QTY. OF COTTON SEED (IN QTLS)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Container(
                            color: const Color(0xFFE2E8F0),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            alignment: Alignment.center,
                            child: const Text(
                                'PROGRESSIVE DELIVERY (IN QTLS)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            color: const Color(0xFFE2E8F0),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            alignment: Alignment.center,
                            child: const Text(
                                'SOLD BUT NOT LIFTED QTY (IN QTLS)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            alignment: Alignment.center,
                            child: const Text(
                                'MARKET RATE MIN\n(In Rs.)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            alignment: Alignment.center,
                            child: const Text(
                                'MARKET RATE MAX\n(In Rs.)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(
                          width: 80,
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('ACTIONS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: headerBg,
                      border: Border(
                        top: BorderSide(color: borderColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        headerCell('', flex: 1),
                        headerCell('', flex: 2),
                        headerCell('', flex: 3),
                        headerCell('', flex: 2),
                        headerCell('REALISABLE', flex: 1),
                        headerCell('REALISED', flex: 1),
                        headerCell('SOLD QTY', flex: 1),
                        headerCell('UNSOLD\nQTY', flex: 1),
                        headerCell('KAPAS', flex: 1),
                        headerCell('READY', flex: 1),
                        headerCell('TOTAL', flex: 1),
                        headerCell('KAPAS', flex: 1),
                        headerCell('READY', flex: 1),
                        headerCell('TOTAL', flex: 1),
                        headerCell('', flex: 2),
                        headerCell('', flex: 2),
                        const SizedBox(width: 80),
                      ],
                    ),
                  ),
                  ..._seedFactories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final f = entry.value;

                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: borderColor),
                        ),
                      ),
                      child: Row(
                        children: [
                          dataCell('${index + 1}', flex: 1),
                          dataCell(_selectedCentre ?? '', flex: 2),
                          dataCell(f.factoryName, flex: 3),
                          dataCell(f.variety, flex: 2),
                          dataCell(fmt(f.realisable), flex: 1),
                          dataCell(fmt(f.realised), flex: 1),
                          dataCell(fmt(f.soldQty), flex: 1),
                          dataCell(fmt(f.progDelivery), flex: 1),
                          dataCell(fmt(f.kaps1), flex: 1),
                          dataCell(fmt(f.ready1), flex: 1),
                          dataCell(fmt(f.total1), flex: 1, bold: true),
                          dataCell(fmt(f.kaps2), flex: 1),
                          dataCell(fmt(f.ready2), flex: 1),
                          dataCell(fmt(f.total2), flex: 1, bold: true),
                          dataCell(fmt(f.marketRateMin), flex: 2),
                          dataCell(fmt(f.marketRateMax), flex: 2),
                          SizedBox(
                            width: 80,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      _openEditSeedFactoryDialog(index),
                                  icon: const Icon(Icons.edit,
                                      size: 16, color: Color(0xFFF59E0B)),
                                  tooltip: 'Edit',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  onPressed: () => _deleteSeedFactory(index),
                                  icon: const Icon(Icons.delete,
                                      size: 16, color: Colors.red),
                                  tooltip: 'Delete',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
          maxWidth: 1300,
          maxHeight: 850,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.eco_rounded,
                          color: Color(0xFF0F172A), size: 24),
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
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      CommonFormWidgets.sectionHeader(
                                          'Header Information'),
                                      TextButton.icon(
                                        onPressed: _isSubmitting
                                            ? null
                                            : _resetLookup,
                                        icon: const Icon(Icons.search,
                                            size: 16),
                                        label:
                                        const Text('Change entry'),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                          const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                CommonFormWidgets.sectionHeader(
                                    'Header Information'),

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
                                        if (value != null) {
                                          _autoGenerateReportNo();
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: CommonFormWidgets.textField(
                                      controller: _reportNoController,
                                      label: 'Report No.',
                                      hint: _isLoadingReportNo
                                          ? 'Generating...'
                                          : 'e.g., 1',
                                      icon: Icons.numbers,
                                      keyboardType:
                                      TextInputType.number,
                                      readOnly: widget.isModify ||
                                          _isLoadingReportNo,
                                      suffixIcon: _isLoadingReportNo
                                          ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child:
                                          CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                          : null,
                                      validator: (value) {
                                        if (value == null ||
                                            value.isEmpty) {
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
                                onTap: widget.isModify
                                    ? null
                                    : () => _selectDate(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.grey[300]!),
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today,
                                          color: Color(0xFF64748B)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Date: ${CommonFormWidgets.formatDate(_selectedDate)}',
                                          style: const TextStyle(
                                              fontSize: 16),
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
                                    child: OutlinedButton.icon(
                                      onPressed: _isSubmitting
                                          ? null
                                          : _showPreview,
                                      icon: const Icon(Icons.visibility,
                                          size: 16),
                                      label: const Text('Preview'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : () =>
                                          Navigator.of(context).pop(),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : _submitForm,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                        const Color(0xFF0F172A),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _isSubmitting
                                          ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child:
                                        CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                          AlwaysStoppedAnimation<
                                              Color>(Colors.white),
                                        ),
                                      )
                                          : Text(
                                        widget.isModify
                                            ? 'Update'
                                            : 'Submit',
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