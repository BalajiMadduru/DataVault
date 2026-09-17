import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/apiservice.dart';

class ReportsListScreen extends StatefulWidget {
  final String reportType;

  const ReportsListScreen({
    super.key,
    required this.reportType,
  });

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

enum _DateFilterMode { single, range }

class _ReportsListScreenState extends State<ReportsListScreen> {
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _filteredReports = [];
  bool _isLoading = true;
  bool _isDeleting = false;

  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  _DateFilterMode _filterMode = _DateFilterMode.single;
  String? _selectedCentreFilter;
  String? _selectedVarietyFilter;

  bool get _isDateFilterActive =>
      _filterStartDate != null || _filterEndDate != null;

  bool get _isFilterActive =>
      _isDateFilterActive ||
          _selectedCentreFilter != null ||
          _selectedVarietyFilter != null;

  List<String> get _availableCentres {
    final centres = <String>{};
    for (final r in _reports) {
      final c = r['centre']?.toString();
      if (c != null && c.isNotEmpty) centres.add(c);
    }
    return centres.toList()..sort();
  }

  List<String> get _availableVarieties {
    if (widget.reportType != 'purchase') return [];
    final v = <String>{};
    for (final r in _reports) {
      final s = r['variety']?.toString();
      if (s != null && s.isNotEmpty) v.add(s);
    }
    return v.toList()..sort();
  }

  /// Filtered reports grouped by centre + date + reportNo.
  List<MapEntry<String, Map<String, Map<String, dynamic>>>>
  get _groupedFilteredReports {
    final groups = <String, Map<String, Map<String, dynamic>>>{};

    for (final r in _filteredReports) {
      final centre = (r['centre'] ?? '').toString();
      final date = (r['date'] ?? '').toString().split('T').first;
      final reportNo = (r['reportNo'] ?? '').toString();
      final variety = (r['variety'] ?? '').toString();
      final key = '$centre|$date|$reportNo';
      groups.putIfAbsent(key, () => {})[variety] = r;
    }

    return groups.entries.toList();
  }

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  // ====================================================================
  // Helpers
  // ====================================================================

  String _val(Map<String, dynamic>? doc, String field) {
    if (doc == null) return '0';
    final v = doc[field];
    if (v == null) return '0';
    return v.toString();
  }

  String _progVal(
      Map<String, dynamic>? bbMod,
      Map<String, dynamic>? bbSplMod,
      Map<String, dynamic>? mech,
      String targetVariety,
      String field,
      ) {
    final ownDoc = {
      'BB MOD': bbMod,
      'BB SPL MOD': bbSplMod,
      'MECH': mech,
    }[targetVariety];

    if (ownDoc != null && ownDoc[field] != null) {
      return ownDoc[field].toString();
    }

    final owner = bbMod ?? bbSplMod ?? mech;
    final others = owner?['otherVarietiesProgressive'];
    if (others is Map) {
      final other = others[targetVariety];
      if (other is Map && other[field] != null) {
        return other[field].toString();
      }
    }
    return '0';
  }

  String _fmtDateDisplay(dynamic d) {
    if (d == null) return '';
    try {
      final date = d is String ? DateTime.parse(d) : d as DateTime;
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (_) {
      return '';
    }
  }

  // ====================================================================
  // Filters
  // ====================================================================

  Future<void> _selectSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _filterStartDate ?? DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: const Color(0xFF0F172A)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _filterStartDate = picked;
        _filterEndDate = picked;
      });
      _applyFilters();
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _filterStartDate != null && _filterEndDate != null
          ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!)
          : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: const Color(0xFF0F172A)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _filterStartDate = picked.start;
        _filterEndDate = picked.end;
      });
      _applyFilters();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _filterStartDate = null;
      _filterEndDate = null;
    });
    _applyFilters();
  }

  void _setFilterMode(_DateFilterMode mode) {
    if (_filterMode == mode) return;
    setState(() {
      _filterMode = mode;
      _filterStartDate = null;
      _filterEndDate = null;
    });
    _applyFilters();
  }

  void _openDatePicker() {
    if (_filterMode == _DateFilterMode.single) {
      _selectSingleDate();
    } else {
      _selectDateRange();
    }
  }

  void _clearCentreFilter() {
    setState(() => _selectedCentreFilter = null);
    _applyFilters();
  }

  void _clearVarietyFilter() {
    setState(() => _selectedVarietyFilter = null);
    _applyFilters();
  }

  void _clearAllFilters() {
    setState(() {
      _filterStartDate = null;
      _filterEndDate = null;
      _selectedCentreFilter = null;
      _selectedVarietyFilter = null;
    });
    _applyFilters();
  }

  String _formatFilterDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  void _applyFilters() {
    setState(() {
      _filteredReports = _reports.where((report) {
        final rawDate = report['date']?.toString();
        if (rawDate == null || rawDate.isEmpty) return false;
        final reportDate = DateTime.tryParse(rawDate);
        if (reportDate == null) return false;
        final n = DateTime(reportDate.year, reportDate.month, reportDate.day);

        if (_filterStartDate != null) {
          final s = DateTime(_filterStartDate!.year, _filterStartDate!.month,
              _filterStartDate!.day);
          if (n.isBefore(s)) return false;
        }
        if (_filterEndDate != null) {
          final e = DateTime(_filterEndDate!.year, _filterEndDate!.month,
              _filterEndDate!.day);
          if (n.isAfter(e)) return false;
        }
        if (_selectedCentreFilter != null && _selectedCentreFilter!.isNotEmpty) {
          final c = report['centre']?.toString().toLowerCase() ?? '';
          if (c != _selectedCentreFilter!.toLowerCase()) return false;
        }
        if (_selectedVarietyFilter != null && _selectedVarietyFilter!.isNotEmpty) {
          final v = report['variety']?.toString().toLowerCase() ?? '';
          if (v != _selectedVarietyFilter!.toLowerCase()) return false;
        }
        return true;
      }).toList();
    });
  }

  void _loadReports() async {
    setState(() => _isLoading = true);
    final response = widget.reportType == 'purchase'
        ? await ApiService.getPurchaseEntries()
        : await ApiService.getSeedEntries();
    if (mounted) {
      setState(() {
        if (response.success && response.data != null) {
          _reports = List<Map<String, dynamic>>.from(
              response.data!['entries'] ?? []);
        } else {
          _reports = [];
        }
        _isLoading = false;
      });
      _applyFilters();
    }
  }

  // ====================================================================
  // Group reports by (centre + date + reportNo)
  // ====================================================================

  Map<String, Map<String, Map<String, dynamic>>> _groupByReport() {
    final groups = <String, Map<String, Map<String, dynamic>>>{};
    for (final r in _reports) {
      final centre = (r['centre'] ?? '').toString();
      final date = (r['date'] ?? '').toString().split('T').first;
      final reportNo = (r['reportNo'] ?? '').toString();
      final variety = (r['variety'] ?? '').toString();
      final key = '$centre|$date|$reportNo';
      groups.putIfAbsent(key, () => {})[variety] = r;
    }
    return groups;
  }

  // ====================================================================
  // Delete entire group
  // ====================================================================

  Future<void> _deleteGroup(Map<String, Map<String, dynamic>> group) async {
    final sample = group.values.first;
    final docIds = group.values
        .map((r) => r['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    if (docIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete: Report ID not found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final varieties = group.keys.toList()..sort();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Report'),
        content: Text(
          'Delete this report?\n'
              'Centre: ${sample['centre']}\n'
              'Report #${sample['reportNo']}\n'
              'Varieties: ${varieties.join(', ')}\n\n'
              'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    int failed = 0;
    for (final id in docIds) {
      try {
        final response = await ApiService.deleteEntry(id);
        if (!response.success) failed++;
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;

    setState(() {
      _reports.removeWhere((r) => docIds.contains(r['id']?.toString()));
      _isDeleting = false;
    });
    _applyFilters();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? '✅ Report deleted'
              : '⚠️ Deleted ${docIds.length - failed}, $failed failed',
        ),
        backgroundColor: failed == 0 ? Colors.green : Colors.orange,
      ),
    );
  }

  // ====================================================================
  // EXPORT
  // ====================================================================

  Future<void> _exportToExcel() async {
    if (_filteredReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No reports to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (widget.reportType == 'purchase') {
      await _exportPurchaseReportsExcelStyle();
    } else {
      await _exportSeedReports();
    }
  }

  Future<void> _exportPurchaseReportsExcelStyle() async {
    try {
      final groups = _groupByReport();
      int success = 0;
      int fail = 0;

      for (final entry in groups.entries) {
        final parts = entry.key.split('|');
        final centre = parts[0];
        final dateIso = parts[1];
        final reportNo = parts[2];

        final bbMod = entry.value['BB MOD'];
        final bbSplMod = entry.value['BB SPL MOD'];
        final mech = entry.value['MECH'];

        try {
          final excel = excel_lib.Excel.createExcel();

          String sheetName = dateIso.isNotEmpty ? dateIso : 'Report';
          final sheet = excel['Sheet1'];
          if (excel.tables.containsKey('Sheet1') && sheetName != 'Sheet1') {
            excel.delete('Sheet1');
          }

          void row(List<dynamic> cells) => sheet.appendRow(cells);

          row(['', 'THE COTTON CORPORATION OF INDIA LTD']);
          row(['', 'BRANCH OFFICE :: MAHABUBNAGAR.']);
          row(['', 'DAILY PURCHASE REPORT']);
          row(['', 'CROP SEASON 2025-26', '', '', 'MSP']);

          final dateStr = _fmtDateDisplay(dateIso);
          row(['1', 'Purchase Date', ':', dateStr, '', dateStr, '', dateStr]);
          row(['2', 'Centre', ':', centre, '', centre, '', centre]);
          row([
            '3', 'Variety', ':', 'BB MOD', '', 'BB SPL MOD', '', 'MECH',
          ]);

          void dataRow(String n, String label, String field) {
            row([
              n, label, ':',
              _val(bbMod, field), '',
              _val(bbSplMod, field), '',
              _val(mech, field),
            ]);
          }

          dataRow('4',
              "Day's Kapas Purchased from No. of Farmers / No. of Takpatties",
              'farmersDay');
          dataRow('5', 'Arrivals (In Bales)', 'arrivalsBales');
          dataRow('6', 'CCI Purchases (In Qtls)', 'cciPurchaseQtls');
          dataRow('7', 'CCI Purchases (In Bales)', 'cciPurchaseBales');
          dataRow('8', 'Avarage Kapas rate (In Rs. per qtl)', 'avgKapasRate');
          dataRow('9', 'Budgeted Lint Percetage (%)', 'budgetedLint');
          dataRow('10', 'Budgeted Shortage Percetage (%)', 'budgetedShortage');
          dataRow('11', 'Cotton seed Percetage (%)', 'cottonSeedPct');
          dataRow('12', 'Cotton seed rate  (In Rs. per qtl)', 'cottonSeedRate');
          dataRow('13', "Processing cycle (In day's)", 'processingCycle');
          dataRow('14', 'Proforma Expenses (In Rs. per Candy)', 'proformaExpenses');
          dataRow('15', 'Budgeted Padtha (In Rs. per candy)', 'budgetedPadtha');
          dataRow('16', "Day's pressed bales (In Bales)", 'dayPressedBales');
          dataRow('17', 'Market Highest Rate (In Rs. per qtl)', 'marketHighestRate');
          dataRow('18', 'Market Lowest Rate (In Rs. per qtl)', 'marketLowestRate');
          dataRow('19', 'CCI Highest Rate (In Rs. per qtl)', 'cciHighestRate');
          dataRow('20', 'CCI Lowest Rate (In Rs. per qtl)', 'cciLowestRate');

          row([
            '21', 'Prog. Pressed Bales', ':',
            _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPressedBales'), '',
            _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPressedBales'), '',
            _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPressedBales'),
          ]);
          row([
            '22', 'Prog. Purchase in qtls', ':',
            _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPurchaseQtls'), '',
            _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPurchaseQtls'), '',
            _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPurchaseQtls'),
          ]);
          row([
            '23', 'Prog. Purchase Bales', ':',
            _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPurchaseBales'), '',
            _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPurchaseBales'), '',
            _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPurchaseBales'),
          ]);
          row([
            '24',
            'Prog. Kapas Purchased from No. of Farmers  / Prog. No. of Takpatties',
            ':',
            _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progFarmers'), '',
            _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progFarmers'), '',
            _progVal(bbMod, bbSplMod, mech, 'MECH', 'progFarmers'),
          ]);

          row(['25', 'Factory wise day purchase details', ':',
            'BB MOD', '', 'BB SPL MOD', '', 'MECH']);
          row(['', '', '', 'Prog. Pur. in qtls', 'Prog. Pur. in Bales',
            'Prog. Pur. in qtls', 'Prog. Pur. in Bales',
            'Prog. Pur. in qtls', 'Prog. Pur. in Bales']);

          List<Map<String, dynamic>> factories = [];
          final src = bbMod?['factories'] ?? bbSplMod?['factories'] ?? mech?['factories'];
          if (src is List) {
            factories = List<Map<String, dynamic>>.from(src);
          }

          int excelRow = 31;
          for (int i = 0; i < factories.length; i++) {
            final f = factories[i];
            row([
              '', '${i + 1}', f['factoryName']?.toString() ?? '', ':',
              _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPurchaseQtls'),
              _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPurchaseBales'),
              _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPurchaseQtls'),
              _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPurchaseBales'),
              _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPurchaseQtls'),
              _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPurchaseBales'),
            ]);
            excelRow++;
          }

          row([
            '', 'TOTAL', '', ':',
            '=SUM(E31:E$excelRow)', '=SUM(F31:F$excelRow)',
            '=SUM(G31:G$excelRow)', '=SUM(H31:H$excelRow)',
            '=SUM(I31:I$excelRow)', '=SUM(J31:J$excelRow)',
          ]);

          final fileBytes = excel.save();
          if (fileBytes != null) {
            String fileDate = dateStr.replaceAll('.', '-');
            final parts2 = fileDate.split('-');
            String shortDate = fileDate;
            if (parts2.length == 3) {
              final y = parts2[2].length > 2 ? parts2[2].substring(2) : parts2[2];
              shortDate = '${parts2[0]}.${parts2[1]}.$y';
            }
            final fileName =
                'Daily Purchase Report 2025-26 ($centre) - $shortDate.xlsx';

            String? savePath;
            if (Platform.isAndroid || Platform.isIOS) {
              final dir = await getExternalStorageDirectory();
              if (dir != null) savePath = '${dir.path}/$fileName';
            } else {
              final dir = await getApplicationDocumentsDirectory();
              savePath = '${dir.path}/$fileName';
            }
            if (savePath != null) {
              final file = File(savePath);
              await file.writeAsBytes(fileBytes);
              success++;
            }
          }
        } catch (_) {
          fail++;
        }
      }

      if (mounted) {
        String msg = '✅ Exported $success report(s)';
        if (fail > 0) msg += ', $fail failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: fail > 0 ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportSeedReports() async {
    int success = 0;
    int fail = 0;

    final groups = _groupByReport();

    for (final entry in groups.entries) {
      final group = entry.value;
      final sample = group.values.isNotEmpty ? group.values.first : null;

      try {
        final excel = excel_lib.Excel.createExcel();
        final sheet = excel['Sheet1'];

        final factories = _mergedSeedFactories(group);
        if (factories.isEmpty) {
          fail++;
          continue;
        }

        sheet.appendRow(
            ['THE COTTON CORPORATION OF INDIA LTD :: BRANCH OFFICE HUBLI']);
        sheet.appendRow([]);

        final centre =
        (sample?['centre'] ?? 'DEVADURGA').toString().toUpperCase();
        final dateStr = _fmtDateDisplay(sample?['date']);
        final reportNo = sample?['reportNo']?.toString() ?? '1';
        sheet.appendRow(['CENTRE:', centre, '', 'DATE:', dateStr]);
        sheet.appendRow(['REPORT NO.:', reportNo]);
        sheet.appendRow([]);

        sheet.appendRow([
          'S.No.', 'Factory Name', 'Variety',
          'Prog. Realisable', 'Prog. Sold', "Day's Unsold",
          'Kapas Form', 'Ready Form', 'Total', 'Base Rate',
        ]);

        for (int i = 0; i < factories.length; i++) {
          final f = factories[i];
          final kapas = f['kapasForm'] ?? 0;
          final ready = f['readyForm'] ?? 0;
          final total = f['total'] ?? (kapas + ready);
          sheet.appendRow([
            '${i + 1}',
            f['factoryName']?.toString() ?? '',
            f['variety']?.toString() ?? '',
            f['progressiveRealisable']?.toString() ?? '0',
            f['progressiveSold']?.toString() ?? '0',
            f['dayUnsold']?.toString() ?? '0',
            kapas.toString(),
            ready.toString(),
            total.toString(),
            f['baseRate']?.toString() ?? '0',
          ]);
        }

        final bytes = excel.save();
        if (bytes != null) {
          final fileName =
              'Seed_Report_${dateStr.replaceAll('.', '-')}_$reportNo.xlsx';
          String? savePath;
          if (Platform.isAndroid || Platform.isIOS) {
            final dir = await getExternalStorageDirectory();
            if (dir != null) savePath = '${dir.path}/$fileName';
          } else {
            final dir = await getApplicationDocumentsDirectory();
            savePath = '${dir.path}/$fileName';
          }
          if (savePath != null) {
            await File(savePath).writeAsBytes(bytes);
            success++;
          }
        }
      } catch (_) {
        fail++;
      }
    }

    if (mounted) {
      String msg = '✅ Exported $success seed report(s)';
      if (fail > 0) msg += ', $fail failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: fail > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  // ====================================================================
  // Preview
  // ====================================================================

  void _viewReport(Map<String, dynamic> report) {
    if (widget.reportType != 'purchase') {
      _viewSeedReport(report);
      return;
    }

    final centre = (report['centre'] ?? '').toString();
    final date = (report['date'] ?? '').toString().split('T').first;
    final reportNo = (report['reportNo'] ?? '').toString();
    final key = '$centre|$date|$reportNo';

    final groups = _groupByReport();
    final group = groups[key] ?? {};

    final bbMod = group['BB MOD'];
    final bbSplMod = group['BB SPL MOD'];
    final mech = group['MECH'];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 720),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shopping_basket_rounded,
                        color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Purchase Report - $centre',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildExcelStylePurchasePreview(
                      bbMod, bbSplMod, mech),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _exportToExcel();
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _mergedSeedFactories(
      Map<String, Map<String, dynamic>> group) {
    final merged = <Map<String, dynamic>>[];
    for (final doc in group.values) {
      final src = doc['seedFactories'] ?? doc['factories'];
      if (src is List) {
        for (final f in src) {
          if (f is Map) {
            merged.add(Map<String, dynamic>.from(f));
          }
        }
      }
    }
    return merged;
  }

  void _viewSeedReport(Map<String, dynamic> report) {
    final centre = (report['centre'] ?? '').toString();
    final date = (report['date'] ?? '').toString().split('T').first;
    final reportNo = (report['reportNo'] ?? '').toString();
    final key = '$centre|$date|$reportNo';

    final groups = _groupByReport();
    final group = groups[key] ?? {(report['variety'] ?? '').toString(): report};

    final factories = _mergedSeedFactories(group);
    final sample = group.values.isNotEmpty ? group.values.first : report;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 700),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Seed Report - $centre',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildSeedPreviewTable(sample, factories),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _exportToExcel();
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeedPreviewTable(
      Map<String, dynamic>? sample, List<Map<String, dynamic>> factories) {
    final dateStr = _fmtDateDisplay(sample?['date']);
    final centre = (sample?['centre'] ?? '').toString().toUpperCase();
    final reportNo = (sample?['reportNo'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: const Text(
            'SEED REPORT',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('CENTRE:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(centre,
                  style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ),
            const Text('DATE:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(width: 4),
            Text(dateStr, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 16),
            const Text('REPORT NO.:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(width: 4),
            Text(reportNo, style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        if (factories.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No factory data available',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
              WidgetStateProperty.all(const Color(0xFFE2E8F0)),
              columns: const [
                DataColumn(label: Text('S.No.')),
                DataColumn(label: Text('Factory Name')),
                DataColumn(label: Text('Variety')),
                DataColumn(label: Text('Prog. Realisable')),
                DataColumn(label: Text('Prog. Sold')),
                DataColumn(label: Text("Day's Unsold")),
                DataColumn(label: Text('Kapas Form')),
                DataColumn(label: Text('Ready Form')),
                DataColumn(label: Text('Total')),
                DataColumn(label: Text('Base Rate')),
              ],
              rows: factories.asMap().entries.map((e) {
                final i = e.key;
                final f = e.value;
                final total =
                    f['total'] ?? ((f['kapasForm'] ?? 0) + (f['readyForm'] ?? 0));
                return DataRow(cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(Text(f['factoryName']?.toString() ?? '')),
                  DataCell(Text(f['variety']?.toString() ?? '')),
                  DataCell(Text(f['progressiveRealisable']?.toString() ?? '0')),
                  DataCell(Text(f['progressiveSold']?.toString() ?? '0')),
                  DataCell(Text(f['dayUnsold']?.toString() ?? '0')),
                  DataCell(Text(f['kapasForm']?.toString() ?? '0')),
                  DataCell(Text(f['readyForm']?.toString() ?? '0')),
                  DataCell(Text(total.toString())),
                  DataCell(Text(f['baseRate']?.toString() ?? '0')),
                ]);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildExcelStylePurchasePreview(
      Map<String, dynamic>? bbMod,
      Map<String, dynamic>? bbSplMod,
      Map<String, dynamic>? mech,
      ) {
    final dateStr = _fmtDateDisplay(
        bbMod?['date'] ?? bbSplMod?['date'] ?? mech?['date']);
    final centre =
    (bbMod?['centre'] ?? bbSplMod?['centre'] ?? mech?['centre'] ?? '')
        .toString()
        .toUpperCase();

    final rows = <List<String>>[
      ['4', "Day's Kapas Purchased from No. of Farmers / No. of Takpatties",
        _val(bbMod, 'farmersDay'), _val(bbSplMod, 'farmersDay'), _val(mech, 'farmersDay')],
      ['5', 'Arrivals (In Bales)',
        _val(bbMod, 'arrivalsBales'), _val(bbSplMod, 'arrivalsBales'), _val(mech, 'arrivalsBales')],
      ['6', 'CCI Purchases (In Qtls)',
        _val(bbMod, 'cciPurchaseQtls'), _val(bbSplMod, 'cciPurchaseQtls'), _val(mech, 'cciPurchaseQtls')],
      ['7', 'CCI Purchases (In Bales)',
        _val(bbMod, 'cciPurchaseBales'), _val(bbSplMod, 'cciPurchaseBales'), _val(mech, 'cciPurchaseBales')],
      ['8', 'Avarage Kapas rate (In Rs. per qtl)',
        _val(bbMod, 'avgKapasRate'), _val(bbSplMod, 'avgKapasRate'), _val(mech, 'avgKapasRate')],
      ['9', 'Budgeted Lint Percetage (%)',
        _val(bbMod, 'budgetedLint'), _val(bbSplMod, 'budgetedLint'), _val(mech, 'budgetedLint')],
      ['10', 'Budgeted Shortage Percetage (%)',
        _val(bbMod, 'budgetedShortage'), _val(bbSplMod, 'budgetedShortage'), _val(mech, 'budgetedShortage')],
      ['11', 'Cotton seed Percetage (%)',
        _val(bbMod, 'cottonSeedPct'), _val(bbSplMod, 'cottonSeedPct'), _val(mech, 'cottonSeedPct')],
      ['12', 'Cotton seed rate  (In Rs. per qtl)',
        _val(bbMod, 'cottonSeedRate'), _val(bbSplMod, 'cottonSeedRate'), _val(mech, 'cottonSeedRate')],
      ['13', "Processing cycle (In day's)",
        _val(bbMod, 'processingCycle'), _val(bbSplMod, 'processingCycle'), _val(mech, 'processingCycle')],
      ['14', 'Proforma Expenses (In Rs. per Candy)',
        _val(bbMod, 'proformaExpenses'), _val(bbSplMod, 'proformaExpenses'), _val(mech, 'proformaExpenses')],
      ['15', 'Budgeted Padtha (In Rs. per candy)',
        _val(bbMod, 'budgetedPadtha'), _val(bbSplMod, 'budgetedPadtha'), _val(mech, 'budgetedPadtha')],
      ['16', "Day's pressed bales (In Bales)",
        _val(bbMod, 'dayPressedBales'), _val(bbSplMod, 'dayPressedBales'), _val(mech, 'dayPressedBales')],
      ['17', 'Market Highest Rate (In Rs. per qtl)',
        _val(bbMod, 'marketHighestRate'), _val(bbSplMod, 'marketHighestRate'), _val(mech, 'marketHighestRate')],
      ['18', 'Market Lowest Rate (In Rs. per qtl)',
        _val(bbMod, 'marketLowestRate'), _val(bbSplMod, 'marketLowestRate'), _val(mech, 'marketLowestRate')],
      ['19', 'CCI Highest Rate (In Rs. per qtl)',
        _val(bbMod, 'cciHighestRate'), _val(bbSplMod, 'cciHighestRate'), _val(mech, 'cciHighestRate')],
      ['20', 'CCI Lowest Rate (In Rs. per qtl)',
        _val(bbMod, 'cciLowestRate'), _val(bbSplMod, 'cciLowestRate'), _val(mech, 'cciLowestRate')],
      ['21', 'Prog. Pressed Bales',
        _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPressedBales'),
        _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPressedBales'),
        _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPressedBales')],
      ['22', 'Prog. Purchase in qtls',
        _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPurchaseQtls'),
        _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPurchaseQtls'),
        _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPurchaseQtls')],
      ['23', 'Prog. Purchase Bales',
        _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPurchaseBales'),
        _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPurchaseBales'),
        _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPurchaseBales')],
      ['24', 'Prog. Kapas Purchased from No. of Farmers  / Prog. No. of Takpatties',
        _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progFarmers'),
        _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progFarmers'),
        _progVal(bbMod, bbSplMod, mech, 'MECH', 'progFarmers')],
    ];

    List<Map<String, dynamic>> factories = [];
    final src = bbMod?['factories'] ?? bbSplMod?['factories'] ?? mech?['factories'];
    if (src is List) factories = List<Map<String, dynamic>>.from(src);

    return Container(
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFF94A3B8))),
      child: Column(
        children: [
          _plainHeader('THE COTTON CORPORATION OF INDIA LTD'),
          _plainHeader('BRANCH OFFICE :: MAHABUBNAGAR.'),
          _plainHeader('DAILY PURCHASE REPORT'),
          _plainHeader('CROP SEASON 2025-26', trailing: 'MSP'),
          _numRow('1', 'Purchase Date', dateStr, dateStr, dateStr),
          _numRow('2', 'Centre', centre, centre, centre),
          _numRow('3', 'Variety', 'BB MOD', 'BB SPL MOD', 'MECH', bold: true),
          ...rows.map((r) => _numRow(r[0], r[1], r[2], r[3], r[4])),
          _numRow('25', 'Factory wise day purchase details',
              'BB MOD', 'BB SPL MOD', 'MECH', bold: true),
          _factorySubHeader(),
          if (factories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No factory data available',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            )
          else
            ...factories.asMap().entries.map((e) {
              final i = e.key;
              final f = e.value;
              return _factoryRow(
                '${i + 1}',
                f['factoryName']?.toString() ?? '',
                _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPurchaseQtls'),
                _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPurchaseBales'),
                _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPurchaseQtls'),
                _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPurchaseBales'),
                _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPurchaseQtls'),
                _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPurchaseBales'),
              );
            }),
          _totalRow(bbMod, bbSplMod, mech),
        ],
      ),
    );
  }

  Widget _plainHeader(String text, {String? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      width: double.infinity,
      child: Row(
        children: [
          const SizedBox(width: 32),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          if (trailing != null)
            Text(trailing,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _numRow(String n, String label, String v1, String v2, String v3,
      {bool bold = false}) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Text(n,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B))),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                      color: const Color(0xFF334155))),
            ),
          ),
          _cell(v1, bold: bold),
          _cell(v2, bold: bold),
          _cell(v3, bold: bold),
        ],
      ),
    );
  }

  Widget _cell(String value, {bool bold = false}) {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: Text(value,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF0F172A))),
      ),
    );
  }

  Widget _factorySubHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 32),
          const Expanded(
            flex: 4,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Text('Factory Name',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
          _subCell('Prog. Pur.\nin qtls'),
          _subCell('Prog. Pur.\nin Bales'),
          _subCell('Prog. Pur.\nin qtls'),
          _subCell('Prog. Pur.\nin Bales'),
          _subCell('Prog. Pur.\nin qtls'),
          _subCell('Prog. Pur.\nin Bales'),
        ],
      ),
    );
  }

  Widget _subCell(String text) {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A))),
      ),
    );
  }

  Widget _factoryRow(
      String sno,
      String name,
      String b1,
      String b2,
      String b3,
      String b4,
      String b5,
      String b6,
      ) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Text(sno,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Text(name,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ),
          ),
          _cell(b1), _cell(b2), _cell(b3), _cell(b4), _cell(b5), _cell(b6),
        ],
      ),
    );
  }

  Widget _totalRow(Map<String, dynamic>? bb, Map<String, dynamic>? spl,
      Map<String, dynamic>? me) {
    double s(String targetVariety, String f) {
      return double.tryParse(_progVal(bb, spl, me, targetVariety, f)) ?? 0;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(top: BorderSide(color: Color(0xFF94A3B8), width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 32),
          const Expanded(
            flex: 4,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Text('TOTAL',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
          _cell(s('BB MOD', 'progPurchaseQtls').toStringAsFixed(2), bold: true),
          _cell(s('BB MOD', 'progPurchaseBales').toStringAsFixed(0), bold: true),
          _cell(s('BB SPL MOD', 'progPurchaseQtls').toStringAsFixed(2), bold: true),
          _cell(s('BB SPL MOD', 'progPurchaseBales').toStringAsFixed(0), bold: true),
          _cell(s('MECH', 'progPurchaseQtls').toStringAsFixed(2), bold: true),
          _cell(s('MECH', 'progPurchaseBales').toStringAsFixed(0), bold: true),
        ],
      ),
    );
  }

  // ====================================================================
  // Build
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    final isPurchase = widget.reportType == 'purchase';
    final availableCentres = _availableCentres;
    final availableVarieties = _availableVarieties;
    final groupedReports = _groupedFilteredReports;

    return Scaffold(
      appBar: AppBar(
        title: Text('${isPurchase ? 'Purchase' : 'Seed'} Reports'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ModeChip(
                      label: 'Single Date',
                      selected: _filterMode == _DateFilterMode.single,
                      onTap: () => _setFilterMode(_DateFilterMode.single),
                    ),
                    _ModeChip(
                      label: 'Date Range',
                      selected: _filterMode == _DateFilterMode.range,
                      onTap: () => _setFilterMode(_DateFilterMode.range),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (availableCentres.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCentreFilter,
                          isExpanded: true,
                          decoration: InputDecoration(
                            hintText: 'All Centres',
                            hintStyle: const TextStyle(
                                fontSize: 12, color: Color(0xFF64748B)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            isDense: true,
                            suffixIcon: _selectedCentreFilter != null
                                ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: _clearCentreFilter,
                              padding: EdgeInsets.zero,
                            )
                                : null,
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Centres'),
                            ),
                            ...availableCentres.map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            )),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedCentreFilter = v);
                            _applyFilters();
                          },
                        ),
                      ),
                      if (isPurchase && availableVarieties.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedVarietyFilter,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: 'All Varieties',
                              hintStyle: const TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              isDense: true,
                              suffixIcon: _selectedVarietyFilter != null
                                  ? IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: _clearVarietyFilter,
                                padding: EdgeInsets.zero,
                              )
                                  : null,
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('All Varieties'),
                              ),
                              ...availableVarieties.map((v) => DropdownMenuItem(
                                value: v,
                                child: Text(v),
                              )),
                            ],
                            onChanged: (v) {
                              setState(() => _selectedVarietyFilter = v);
                              _applyFilters();
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _openDatePicker,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isDateFilterActive
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: _isDateFilterActive
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _isDateFilterActive && _filterStartDate != null
                                      ? (_filterMode == _DateFilterMode.single
                                      ? _formatFilterDate(_filterStartDate!)
                                      : '${_formatFilterDate(_filterStartDate!)} - ${_formatFilterDate(_filterEndDate!)}')
                                      : (_filterMode == _DateFilterMode.single
                                      ? 'Select date'
                                      : 'Select date range'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _isDateFilterActive
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_isDateFilterActive) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _clearDateFilter,
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF64748B),
                      ),
                    ],
                  ],
                ),
                if (_isFilterActive) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (_selectedCentreFilter != null)
                        _FilterChip(
                          label: 'Centre: $_selectedCentreFilter',
                          onPressed: _clearCentreFilter,
                        ),
                      if (_selectedVarietyFilter != null)
                        _FilterChip(
                          label: 'Variety: $_selectedVarietyFilter',
                          onPressed: _clearVarietyFilter,
                        ),
                      if (_isDateFilterActive)
                        _FilterChip(
                          label: _filterMode == _DateFilterMode.single
                              ? 'Date: ${_formatFilterDate(_filterStartDate!)}'
                              : '${_formatFilterDate(_filterStartDate!)} - ${_formatFilterDate(_filterEndDate!)}',
                          onPressed: _clearDateFilter,
                        ),
                      _FilterChip(
                        label: 'Clear All',
                        onPressed: _clearAllFilters,
                        isClearAll: true,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : groupedReports.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isFilterActive
                        ? Icons.search_off_rounded
                        : (isPurchase
                        ? Icons.shopping_basket_outlined
                        : Icons.eco_outlined),
                    size: 64,
                    color: const Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isFilterActive
                        ? 'No data records found'
                        : 'Select filters to view reports',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (_isFilterActive) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _clearAllFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                      ),
                      child: const Text('Clear All Filters'),
                    ),
                  ],
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupedReports.length,
              itemBuilder: (context, index) {
                final groupEntry = groupedReports[index];
                final parts = groupEntry.key.split('|');
                final centre = parts[0];
                final dateIso = parts[1];
                final reportNo = parts[2];
                final group = groupEntry.value;

                final varieties = group.keys.toList()..sort();
                final sample = group.values.first;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: isPurchase
                          ? const Color(0xFFE0F2FE)
                          : const Color(0xFFD1FAE5),
                      child: Icon(
                        isPurchase
                            ? Icons.shopping_basket_rounded
                            : Icons.eco_rounded,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    title: Text(
                      isPurchase
                          ? '$centre - Report #$reportNo'
                          : (sample['factoryName'] ?? centre ?? 'Report'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Date: $dateIso',
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 13),
                        ),
                        Text(
                          'Centre: $centre',
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 13),
                        ),
                        Text(
                          'Varieties: ${varieties.join(', ')}',
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility),
                          onPressed: () => _viewReport(sample),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: _exportToExcel,
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: Colors.red.shade400),
                          onPressed: _isDeleting
                              ? null
                              : () => _deleteGroup(group),
                        ),
                      ],
                    ),
                    onTap: () => _viewReport(sample),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isClearAll;

  const _FilterChip({
    required this.label,
    required this.onPressed,
    this.isClearAll = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isClearAll ? Colors.red.shade50 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isClearAll ? Colors.red.shade200 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isClearAll ? Colors.red.shade700 : const Color(0xFF334155),
              fontWeight: isClearAll ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onPressed,
            child: Icon(
              Icons.close,
              size: 14,
              color:
              isClearAll ? Colors.red.shade700 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}