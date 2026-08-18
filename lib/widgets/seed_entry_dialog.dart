import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this for LogicalKeyboardKey
import 'create_entry_dialog_base.dart';
import '../enums/report_type.dart';
import '../services/apiservice.dart';

class SeedCreateEntryDialog extends StatefulWidget {
  final bool isModify;
  final Map<String, dynamic>? existingData;

  const SeedCreateEntryDialog({
    super.key,
    this.isModify = false,
    this.existingData,
  });

  @override
  State<SeedCreateEntryDialog> createState() =>
      _SeedCreateEntryDialogState();
}

class _SeedCreateEntryDialogState
    extends CreateEntryDialogState<SeedCreateEntryDialog> {
  List<FactoryData> seedFactories = [];

  final List<String> varieties = [
    'BB MOD',
    'H-4',
    'DCH-32',
    'Suvin',
    'J-34',
    'LRA',
  ];

  @override
  ReportType get reportType => ReportType.dailySeed;
  @override
  String get reportTypeLabel => 'Seed';
  @override
  Color get accentColor => const Color(0xFFD1FAE5);
  @override
  IconData get iconData => Icons.eco_rounded;
  @override
  String get routeKey => 'seed';

  @override
  void loadExistingData(Map<String, dynamic> data) {
    final centre = data['centre'] as String?;
    selectedCentre = (centre != null && centre.isNotEmpty) ? centre : null;
    reportNoController.text = data['reportNo']?.toString() ?? '';

    // FIX: Use proper type casting with Map<String, dynamic>
    if (data['seedFactories'] is List) {
      seedFactories = (data['seedFactories'] as List)
          .map((f) => FactoryData.fromJson(Map<String, dynamic>.from(f as Map<String, dynamic>)))
          .toList();
    }

    if (data['date'] != null) {
      selectedDate = DateTime.parse(data['date']);
    }
  }

  @override
  Future<void> onCentreSelected(String centre) async {
    await autoGenerateReportNo();
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
                  ? 'Seed Report Updated Successfully!'
                  : 'Seed Report Created Successfully!',
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

      final data = {
        'reportType': reportType.label,
        'date': selectedDate.toIso8601String(),
        'centre': selectedCentre ?? '',
        'reportNo': int.tryParse(reportNoController.text) ?? 0,
        'seedFactories': seedFactories.map((f) => f.toJson()).toList(),
      };

      final ApiResponse response;
      if (widget.isModify && docId != null) {
        response = await ApiService.updateEntry(docId!, data);
      } else {
        response = await ApiService.saveSeedEntry(data);
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

  void _openAddSeedFactoryDialog() {
    _showSeedFactoryFormDialog(null);
  }

  void _openEditSeedFactoryDialog(int index) {
    _showSeedFactoryFormDialog(seedFactories[index]);
  }

  void _showSeedFactoryFormDialog(FactoryData? factoryData) {
    final nameController = TextEditingController(text: factoryData?.factoryName ?? '');
    String? selectedVariety = factoryData?.variety;
    final realisableController = TextEditingController(text: factoryData?.progressiveRealisable.toString() ?? '');
    final soldController = TextEditingController(text: factoryData?.progressiveSold.toString() ?? '');
    final unsoldController = TextEditingController(text: factoryData?.dayUnsold.toString() ?? '');
    final kapasController = TextEditingController(text: factoryData?.kapasForm.toString() ?? '');
    final readyController = TextEditingController(text: factoryData?.readyForm.toString() ?? '');
    final baseRateController = TextEditingController(text: factoryData?.baseRate.toString() ?? '');

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

                      DropdownButtonFormField<String>(
                        initialValue: selectedVariety ?? varieties.first,
                        decoration: InputDecoration(
                          labelText: 'Variety',
                          hintText: 'Select variety',
                          prefixIcon: const Icon(Icons.eco, color: Color(0xFF64748B)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: varieties.map((String variety) {
                          return DropdownMenuItem(
                            value: variety,
                            child: Text(variety),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedVariety = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a variety';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: buildTextField(
                              controller: realisableController,
                              label: 'Progressive Realisable (Total)',
                              hint: 'e.g., 70',
                              icon: Icons.trending_up,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: buildTextField(
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
                      Row(
                        children: [
                          Expanded(
                            child: buildTextField(
                              controller: unsoldController,
                              label: 'Day\'s Unsold',
                              hint: 'e.g., 70',
                              icon: Icons.inbox,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: buildTextField(
                              controller: kapasController,
                              label: 'Kapas Form',
                              hint: 'e.g., 0',
                              icon: Icons.format_align_left,
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
                              controller: readyController,
                              label: 'Ready Form',
                              hint: 'e.g., 70',
                              icon: Icons.check_circle_outline,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: buildTextField(
                              controller: baseRateController,
                              label: 'Base Rate',
                              hint: 'e.g., 3700',
                              icon: Icons.currency_rupee,
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
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (factoryFormKey.currentState!.validate()) {
                    final progressiveRealisable = int.tryParse(realisableController.text) ?? 0;
                    final progressiveSold = int.tryParse(soldController.text) ?? 0;
                    final dayUnsold = int.tryParse(unsoldController.text) ?? 0;
                    final kapasForm = int.tryParse(kapasController.text) ?? 0;
                    final readyForm = int.tryParse(readyController.text) ?? 0;
                    final total = kapasForm + readyForm;

                    final factory = FactoryData(
                      factoryName: nameController.text,
                      variety: selectedVariety ?? '',
                      progressiveRealisable: progressiveRealisable,
                      progressiveSold: progressiveSold,
                      dayUnsold: dayUnsold,
                      kapasForm: kapasForm,
                      readyForm: readyForm,
                      total: total,
                      baseRate: int.tryParse(baseRateController.text) ?? 0,
                    );

                    setState(() {
                      if (isEditing) {
                        final index = seedFactories.indexOf(factoryData);
                        seedFactories[index] = factory;
                      } else {
                        seedFactories.add(factory);
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                seedFactories.removeAt(index);
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

  Widget _buildSeedFactoryTable() {
    if (seedFactories.isEmpty) {
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
          columnSpacing: 12,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
          columns: const [
            DataColumn(label: Text('S.No.', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ginning & pressing factory name', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Variety', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Progressive Realisable (Total)', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Progressive Sold', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Day\'s Unsold', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Kapas Form', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ready Form', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Base Rate', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: seedFactories.asMap().entries.map((entry) {
            final index = entry.key;
            final factory = entry.value;
            return DataRow(
              cells: [
                DataCell(Text('${index + 1}')),
                DataCell(SizedBox(
                  width: 200,
                  child: Text(
                    factory.factoryName,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
                DataCell(Text(factory.variety)),
                DataCell(Text(factory.progressiveRealisable.toString())),
                DataCell(Text(factory.progressiveSold.toString())),
                DataCell(Text(factory.dayUnsold.toString())),
                DataCell(Text(factory.kapasForm.toString())),
                DataCell(Text(factory.readyForm.toString())),
                DataCell(Text(factory.total.toString())),
                DataCell(Text(factory.baseRate.toString())),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _openEditSeedFactoryDialog(index),
                        icon: const Icon(Icons.edit, size: 18, color: Color(0xFFF59E0B)),
                        tooltip: 'Edit',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _deleteSeedFactory(index),
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
  Widget build(BuildContext context) {
    if (widget.isModify && !entryFound) {
      return _buildLookupDialog();
    }
    return _buildSeedFormDialog();
  }

  Widget _buildLookupDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Focus(
        focusNode: dialogFocusNode,
        autofocus: true,
        child: CallbackShortcuts(
          bindings: {
            SingleActivator(LogicalKeyboardKey.escape): () {
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
                            'Find Seed Entry',
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

  Widget _buildSeedFormDialog() {
    final title = widget.isModify ? 'Modify' : 'Add';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Focus(
        focusNode: dialogFocusNode,
        autofocus: true,
        child: CallbackShortcuts(
          bindings: {
            SingleActivator(LogicalKeyboardKey.escape): () {
              Navigator.of(context).pop();
            },
            SingleActivator(LogicalKeyboardKey.arrowUp): () {
              scrollController.animateTo(
                scrollController.offset - 50,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            },
            SingleActivator(LogicalKeyboardKey.arrowDown): () {
              scrollController.animateTo(
                scrollController.offset + 50,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            },
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
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
                            '$title Seed Report',
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

                    Row(
                      children: [
                        Expanded(
                          child: buildCentreDropdown(readOnly: widget.isModify),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildTextField(
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
                        ),
                      ],
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
                    const SizedBox(height: 20),

                    buildSectionHeaderWithAction(
                      'Ginning & Pressing Factory Details',
                      actionLabel: 'Add Factory',
                      onAction: _openAddSeedFactoryDialog,
                    ),
                    const SizedBox(height: 12),
                    _buildSeedFactoryTable(),
                    const SizedBox(height: 20),

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