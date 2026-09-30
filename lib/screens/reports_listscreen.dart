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
      final date = _dateKey(r['date']);
      final reportNo = (r['reportNo'] ?? '').toString();

      // For weight list, use a single key without variety
      if (widget.reportType == 'weightList') {
        final key = '$centre|$date|$reportNo';
        groups.putIfAbsent(key, () => {})['weightList'] = r;
      } else {
        final variety = (r['variety'] ?? '').toString();
        final key = '$centre|$date|$reportNo';
        groups.putIfAbsent(key, () => {})[variety] = r;
      }
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

  double _n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

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

  /// Parses String (ISO or dd/MM/yyyy or dd.MM.yyyy), DateTime or Firestore
  /// Timestamp into a DateTime. Returns null if it can't be parsed.
  DateTime? _parseAnyDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      final iso = DateTime.tryParse(s);
      if (iso != null) return iso;
      final m = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$').firstMatch(s);
      if (m != null) {
        return DateTime(
            int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
      }
      return null;
    }
    try {
      // Firestore Timestamp (avoids needing the cloud_firestore import here)
      final d = (v as dynamic).toDate();
      if (d is DateTime) return d;
    } catch (_) {}
    return null;
  }

  /// yyyy-MM-dd string for grouping/keys.
  String _dateKey(dynamic v) {
    final d = _parseAnyDate(v);
    if (d == null) return (v ?? '').toString().split('T').first;
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _fmtDateDisplay(dynamic d) {
    if (d == null) return '';
    try {
      final date = _parseAnyDate(d);
      if (date == null) return '';
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
        final reportDate = _parseAnyDate(report['date']);
        if (reportDate == null && _isDateFilterActive) return false;
        final n = reportDate == null
            ? null
            : DateTime(reportDate.year, reportDate.month, reportDate.day);

        if (n != null && _filterStartDate != null) {
          final s = DateTime(_filterStartDate!.year, _filterStartDate!.month,
              _filterStartDate!.day);
          if (n.isBefore(s)) return false;
        }
        if (n != null && _filterEndDate != null) {
          final e = DateTime(_filterEndDate!.year, _filterEndDate!.month,
              _filterEndDate!.day);
          if (n.isAfter(e)) return false;
        }
        if (_selectedCentreFilter != null && _selectedCentreFilter!.isNotEmpty) {
          final c = report['centre']?.toString().toLowerCase() ?? '';
          if (c != _selectedCentreFilter!.toLowerCase()) return false;
        }
        if (_selectedVarietyFilter != null &&
            _selectedVarietyFilter!.isNotEmpty) {
          final v = report['variety']?.toString().toLowerCase() ?? '';
          if (v != _selectedVarietyFilter!.toLowerCase()) return false;
        }
        return true;
      }).toList();
    });
  }

  void _loadReports() async {
    setState(() => _isLoading = true);
    ApiResponse response;

    if (widget.reportType == 'purchase') {
      response = await ApiService.getPurchaseEntries();
    } else if (widget.reportType == 'seed') {
      response = await ApiService.getSeedEntries();
    } else if (widget.reportType == 'weightList') {
      response = await ApiService.getWeightListEntries();
    } else {
      response = ApiResponse(success: false, message: 'Unknown report type');
    }

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
      debugPrint('[Reports] ${widget.reportType}: loaded ${_reports.length} reports'
          '${response.success ? '' : ' (ERROR: ${response.message})'}');
      if (!response.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 6),
          ),
        );
      }
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
      final date = _dateKey(r['date']);
      final reportNo = (r['reportNo'] ?? '').toString();
      final key = '$centre|$date|$reportNo';

      if (widget.reportType == 'weightList') {
        // Weight lists have a single entry per report — use a fixed inner key
        groups.putIfAbsent(key, () => {})['weightList'] = r;
      } else {
        final variety = (r['variety'] ?? '').toString();
        groups.putIfAbsent(key, () => {})[variety] = r;
      }
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
    } else if (widget.reportType == 'weightList') {
      // Export all weight list reports
      for (final report in _filteredReports) {
        await _exportWeightListToExcel(report);
      }
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
            '3',
            'Variety',
            ':',
            'BB MOD',
            '',
            'BB SPL MOD',
            '',
            'MECH',
          ]);

          void dataRow(String n, String label, String field) {
            row([
              n,
              label,
              ':',
              _val(bbMod, field),
              '',
              _val(bbSplMod, field),
              '',
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
          dataRow('9', 'Moisture (%)', 'moisture');
          dataRow('10', 'Budgeted Lint Percetage (%)', 'budgetedLint');
          dataRow('11', 'Budgeted Shortage Percetage (%)', 'budgetedShortage');
          dataRow('12', 'Cotton seed Percetage (%)', 'cottonSeedPct');
          dataRow('13', 'Cotton seed rate  (In Rs. per qtl)', 'cottonSeedRate');
          dataRow('14', "Processing cycle (In day's)", 'processingCycle');
          dataRow('15', 'Proforma Expenses (In Rs. per Candy)',
              'proformaExpenses');
          dataRow('16', 'Budgeted Padtha (In Rs. per candy)', 'budgetedPadtha');
          dataRow('17', "Day's pressed bales (In Bales)", 'dayPressedBales');
          dataRow('18', 'Market Highest Rate (In Rs. per qtl)',
              'marketHighestRate');
          dataRow('19', 'Market Lowest Rate (In Rs. per qtl)',
              'marketLowestRate');
          dataRow('20', 'CCI Highest Rate (In Rs. per qtl)', 'cciHighestRate');
          dataRow('21', 'CCI Lowest Rate (In Rs. per qtl)', 'cciLowestRate');

          row([
            '22',
            'Prog. Pressed Bales',
            ':',
            _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPressedBales'),
            '',
            _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPressedBales'),
            '',
            _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPressedBales'),
          ]);
          row([
            '23',
            'Prog. Purchase in qtls',
            ':',
            _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPurchaseQtls'),
            '',
            _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPurchaseQtls'),
            '',
            _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPurchaseQtls'),
          ]);
          row([
            '24',
            'Prog. Purchase Bales',
            ':',
            _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPurchaseBales'),
            '',
            _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPurchaseBales'),
            '',
            _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPurchaseBales'),
          ]);
          row([
            '25',
            'Prog. Kapas Purchased from No. of Farmers  / Prog. No. of Takpatties',
            ':',
            _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progFarmers'),
            '',
            _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progFarmers'),
            '',
            _progVal(bbMod, bbSplMod, mech, 'MECH', 'progFarmers'),
          ]);

          row([
            '26',
            'Factory wise day purchase details',
            ':',
            'BB MOD',
            '',
            'BB SPL MOD',
            '',
            'MECH'
          ]);
          row([
            '',
            '',
            '',
            'Prog. Pur. in qtls',
            'Prog. Pur. in Bales',
            'Prog. Pur. in qtls',
            'Prog. Pur. in Bales',
            'Prog. Pur. in qtls',
            'Prog. Pur. in Bales'
          ]);

          List<Map<String, dynamic>> factories = [];
          final src =
              bbMod?['factories'] ?? bbSplMod?['factories'] ?? mech?['factories'];
          if (src is List) {
            factories = List<Map<String, dynamic>>.from(src);
          }

          int excelRow = 31;
          for (int i = 0; i < factories.length; i++) {
            final f = factories[i];
            row([
              '',
              '${i + 1}',
              f['factoryName']?.toString() ?? '',
              ':',
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
            '',
            'TOTAL',
            '',
            ':',
            '=SUM(E31:E$excelRow)',
            '=SUM(F31:F$excelRow)',
            '=SUM(G31:G$excelRow)',
            '=SUM(H31:H$excelRow)',
            '=SUM(I31:I$excelRow)',
            '=SUM(J31:J$excelRow)',
          ]);

          final fileBytes = excel.save();
          if (fileBytes != null) {
            String fileDate = dateStr.replaceAll('.', '-');
            final parts2 = fileDate.split('-');
            String shortDate = fileDate;
            if (parts2.length == 3) {
              final y = parts2[2].length > 2
                  ? parts2[2].substring(2)
                  : parts2[2];
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
          'Sno',
          'Centre',
          'Name of Factory',
          'Variety',
          'Realisable',
          'Realised',
          'Sold Quantity',
          'Progressive Delivery',
          'KAPAS (1)',
          'READY (1)',
          'TOTAL (1)',
          'KAPAS (2)',
          'READY (2)',
          'TOTAL (2)',
          'Market Rate (Min)',
          'Market Rate (Max)',
        ]);

        for (int i = 0; i < factories.length; i++) {
          final f = factories[i];
          final realisable = _n(f['realisable'] ?? f['progressiveRealisable']);
          final realised = _n(f['realised'] ?? f['progressiveSold']);
          final soldQty = _n(f['soldQty']);
          final progDelivery = _n(f['progDelivery']);

          final ready1 = realised < soldQty ? 0.0 : realised - soldQty;
          final kaps1 = realisable - soldQty - ready1;
          final total1 = kaps1 + ready1;

          final kaps2 = realised > soldQty ? 0.0 : soldQty - realised;
          final ready2 = soldQty - progDelivery - kaps2;
          final total2 = kaps2 + ready2;

          sheet.appendRow([
            '${i + 1}',
            centre,
            f['factoryName']?.toString() ?? '',
            f['variety']?.toString() ?? '',
            realisable,
            realised,
            soldQty,
            progDelivery,
            kaps1,
            ready1,
            total1,
            kaps2,
            ready2,
            total2,
            _n(f['marketRateMin']),
            _n(f['marketRateMax']),
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

  Future<void> _exportWeightListToExcel(Map<String, dynamic> data) async {
    try {
      final excel = excel_lib.Excel.createExcel();
      final sheet = excel['Sheet1'];

      final dateStr = _fmtDateDisplay(data['date']);
      final centre = (data['centre'] ?? '').toString().toUpperCase();
      final variety = (data['variety'] ?? '').toString();
      final pmNo = (data['pmNo'] ?? '').toString();
      final prNo = (data['prNo'] ?? '').toString();
      final lotNo = (data['lotNo'] ?? '').toString();
      final sampleBaleNo = (data['sampleBaleNo'] ?? '').toString();
      final godown = (data['godown'] ?? '').toString();
      final noOfBales = (data['noOfBales'] ?? 100).toString();
      final moisture = (data['moisture'] ?? '').toString();
      final pressingFactory = (data['pressingFactory'] ?? '').toString();

      // Parse bale entries
      List<Map<String, dynamic>> baleEntries = [];
      final baleSrc = data['baleEntries'];
      if (baleSrc is List) {
        baleEntries = List<Map<String, dynamic>>.from(baleSrc);
      }

      final tareWeight = _n(data['tareWeight']);
      final totalGrossWeight = _n(data['totalGrossWeight']);
      final totalNettWeight = _n(data['totalNettWeight']);

      String fmt(double v) {
        if (v == v.roundToDouble()) return v.toInt().toString();
        return v.toStringAsFixed(2);
      }

      // Header rows
      sheet.appendRow(['', 'THE COTTON CORPORATION OF INDIA LTD']);
      sheet.appendRow(['', 'BRANCH OFFICE :: MAHABUBNAGAR']);
      sheet.appendRow(['', 'CENTRE :: $centre']);
      sheet.appendRow([]);
      sheet.appendRow(['', 'P.MARK NO: $pmNo', '', 'P.R.NO: $prNo']);
      sheet.appendRow(
          ['', 'VARIETY: $variety', '', 'Sample Bale No: $sampleBaleNo']);
      sheet.appendRow(['', 'LOT NO: $lotNo', '', 'GODOWN: $godown']);
      sheet.appendRow(
          ['', 'NO OF BALES: $noOfBales', '', 'MOISTURE: $moisture']);
      sheet.appendRow(['', 'DATE OF PRESSING: $dateStr']);
      sheet.appendRow(
          ['', 'NAME OF THE PRESSING FACTORY: $pressingFactory']);
      sheet.appendRow([]);

      // Bale table header
      final headerRow = <String>[];
      for (int c = 0; c < 5; c++) {
        headerRow.add('NO');
        headerRow.add('Kgs.');
      }
      sheet.appendRow(headerRow);

      // Bale data - 10 rows per section, 5 columns
      final totalBales = baleEntries.length;
      for (int section = 0; section < (totalBales / 50).ceil(); section++) {
        final sectionStart = section * 50;
        final sectionEnd = (sectionStart + 50).clamp(0, totalBales);

        // 10 rows of data
        for (int r = 0; r < 10; r++) {
          final rowData = <String>[];
          for (int c = 0; c < 5; c++) {
            final idx = sectionStart + r + (c * 10);
            if (idx < sectionEnd && idx < baleEntries.length) {
              rowData.add('${idx + 1}');
              rowData.add(fmt(_n(baleEntries[idx]['weight'])));
            } else {
              rowData.add('');
              rowData.add('');
            }
          }
          sheet.appendRow(rowData);
        }

        // Total row
        final totalRow = <String>[];
        for (int c = 0; c < 5; c++) {
          double colTotal = 0;
          for (int r = 0; r < 10; r++) {
            final idx = sectionStart + r + (c * 10);
            if (idx < sectionEnd && idx < baleEntries.length) {
              colTotal += _n(baleEntries[idx]['weight']);
            }
          }
          totalRow.add(c == 0 ? 'TOTAL' : '');
          totalRow.add(fmt(colTotal));
        }
        sheet.appendRow(totalRow);
        sheet.appendRow([]);
      }

      // Summary
      sheet.appendRow([
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'Total Grass Weight :',
        fmt(totalGrossWeight)
      ]);
      sheet.appendRow([
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'Tare Weight:',
        fmt(tareWeight)
      ]);
      sheet.appendRow([
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'Total Nett Weight:',
        fmt(totalNettWeight)
      ]);

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final fileName =
            'Weight_List_${centre}_${dateStr.replaceAll('.', '-')}.xlsx';
        String? savePath;

        if (Platform.isAndroid || Platform.isIOS) {
          final dir = await getExternalStorageDirectory();
          if (dir != null) savePath = '${dir.path}/$fileName';
        } else {
          final dir = await getApplicationDocumentsDirectory();
          savePath = '${dir.path}/$fileName';
        }

        if (savePath != null) {
          await File(savePath).writeAsBytes(fileBytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Weight list exported to: $fileName'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
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

  // ====================================================================
  // Preview
  // ====================================================================

  void _viewReport(Map<String, dynamic> report) {
    if (widget.reportType == 'weightList') {
      _viewWeightListReport(report);
      return;
    }

    if (widget.reportType != 'purchase') {
      _viewSeedReport(report);
      return;
    }

    final centre = (report['centre'] ?? '').toString();
    final date = _dateKey(report['date']);
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
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  void _viewWeightListReport(Map<String, dynamic> report) {
    final centre = (report['centre'] ?? '').toString();
    final date = _dateKey(report['date']);
    final reportNo = (report['reportNo'] ?? '').toString();
    final key = '$centre|$date|$reportNo';

    final groups = _groupByReport();
    final group = groups[key] ?? {(report['variety'] ?? '').toString(): report};

    // For weight list, use the first entry as the primary data
    final sample = group.values.isNotEmpty ? group.values.first : report;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.scale_rounded,
                        color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Weight List Report - $centre',
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
                  child: _buildWeightListPreviewTable(sample),
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
                      _exportWeightListToExcel(sample);
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
    final date = _dateKey(report['date']);
    final reportNo = (report['reportNo'] ?? '').toString();
    final key = '$centre|$date|$reportNo';

    final groups = _groupByReport();
    final group = groups[key] ?? {(report['variety'] ?? '').toString(): report};

    final factories = _mergedSeedFactories(group);
    final sample = group.values.isNotEmpty ? group.values.first : report;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

    String fmt(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

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
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
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
                DataColumn(label: Text('Sno')),
                DataColumn(label: Text('Centre')),
                DataColumn(label: Text('Name of Factory')),
                DataColumn(label: Text('Variety')),
                DataColumn(label: Text('Realisable')),
                DataColumn(label: Text('Realised')),
                DataColumn(label: Text('Sold Quantity')),
                DataColumn(label: Text('Progressive Delivery')),
                DataColumn(label: Text('KAPAS (1)')),
                DataColumn(label: Text('READY (1)')),
                DataColumn(label: Text('TOTAL (1)')),
                DataColumn(label: Text('KAPAS (2)')),
                DataColumn(label: Text('READY (2)')),
                DataColumn(label: Text('TOTAL (2)')),
                DataColumn(label: Text('Market Rate (Min)')),
                DataColumn(label: Text('Market Rate (Max)')),
              ],
              rows: factories.asMap().entries.map((e) {
                final i = e.key;
                final f = e.value;

                final realisable =
                _n(f['realisable'] ?? f['progressiveRealisable']);
                final realised = _n(f['realised'] ?? f['progressiveSold']);
                final soldQty = _n(f['soldQty']);
                final progDelivery = _n(f['progDelivery']);

                final ready1 = realised < soldQty ? 0.0 : realised - soldQty;
                final kaps1 = realisable - soldQty - ready1;
                final total1 = kaps1 + ready1;

                final kaps2 = realised > soldQty ? 0.0 : soldQty - realised;
                final ready2 = soldQty - progDelivery - kaps2;
                final total2 = kaps2 + ready2;

                return DataRow(cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(Text(centre)),
                  DataCell(Text(f['factoryName']?.toString() ?? '')),
                  DataCell(Text(f['variety']?.toString() ?? '')),
                  DataCell(Text(fmt(realisable))),
                  DataCell(Text(fmt(realised))),
                  DataCell(Text(fmt(soldQty))),
                  DataCell(Text(fmt(progDelivery))),
                  DataCell(Text(fmt(kaps1))),
                  DataCell(Text(fmt(ready1))),
                  DataCell(Text(fmt(total1))),
                  DataCell(Text(fmt(kaps2))),
                  DataCell(Text(fmt(ready2))),
                  DataCell(Text(fmt(total2))),
                  DataCell(Text(fmt(_n(f['marketRateMin'])))),
                  DataCell(Text(fmt(_n(f['marketRateMax'])))),
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
      [
        '4',
        "Day's Kapas Purchased from No. of Farmers / No. of Takpatties",
        _val(bbMod, 'farmersDay'),
        _val(bbSplMod, 'farmersDay'),
        _val(mech, 'farmersDay')
      ],
      [
        '5',
        'Arrivals (In Bales)',
        _val(bbMod, 'arrivalsBales'),
        _val(bbSplMod, 'arrivalsBales'),
        _val(mech, 'arrivalsBales')
      ],
      [
        '6',
        'CCI Purchases (In Qtls)',
        _val(bbMod, 'cciPurchaseQtls'),
        _val(bbSplMod, 'cciPurchaseQtls'),
        _val(mech, 'cciPurchaseQtls')
      ],
      [
        '7',
        'CCI Purchases (In Bales)',
        _val(bbMod, 'cciPurchaseBales'),
        _val(bbSplMod, 'cciPurchaseBales'),
        _val(mech, 'cciPurchaseBales')
      ],
      [
        '8',
        'Avarage Kapas rate (In Rs. per qtl)',
        _val(bbMod, 'avgKapasRate'),
        _val(bbSplMod, 'avgKapasRate'),
        _val(mech, 'avgKapasRate')
      ],
      [
        '9',
        'Moisture (%)',
        _val(bbMod, 'moisture'),
        _val(bbSplMod, 'moisture'),
        _val(mech, 'moisture')
      ],
      [
        '10',
        'Budgeted Lint Percetage (%)',
        _val(bbMod, 'budgetedLint'),
        _val(bbSplMod, 'budgetedLint'),
        _val(mech, 'budgetedLint')
      ],
      [
        '11',
        'Budgeted Shortage Percetage (%)',
        _val(bbMod, 'budgetedShortage'),
        _val(bbSplMod, 'budgetedShortage'),
        _val(mech, 'budgetedShortage')
      ],
      [
        '12',
        'Cotton seed Percetage (%)',
        _val(bbMod, 'cottonSeedPct'),
        _val(bbSplMod, 'cottonSeedPct'),
        _val(mech, 'cottonSeedPct')
      ],
      [
        '13',
        'Cotton seed rate  (In Rs. per qtl)',
        _val(bbMod, 'cottonSeedRate'),
        _val(bbSplMod, 'cottonSeedRate'),
        _val(mech, 'cottonSeedRate')
      ],
      [
        '14',
        "Processing cycle (In day's)",
        _val(bbMod, 'processingCycle'),
        _val(bbSplMod, 'processingCycle'),
        _val(mech, 'processingCycle')
      ],
      [
        '15',
        'Proforma Expenses (In Rs. per Candy)',
        _val(bbMod, 'proformaExpenses'),
        _val(bbSplMod, 'proformaExpenses'),
        _val(mech, 'proformaExpenses')
      ],
      [
        '16',
        'Budgeted Padtha (In Rs. per candy)',
        _val(bbMod, 'budgetedPadtha'),
        _val(bbSplMod, 'budgetedPadtha'),
        _val(mech, 'budgetedPadtha')
      ],
      [
        '17',
        "Day's pressed bales (In Bales)",
        _val(bbMod, 'dayPressedBales'),
        _val(bbSplMod, 'dayPressedBales'),
        _val(mech, 'dayPressedBales')
      ],
      [
        '18',
        'Market Highest Rate (In Rs. per qtl)',
        _val(bbMod, 'marketHighestRate'),
        _val(bbSplMod, 'marketHighestRate'),
        _val(mech, 'marketHighestRate')
      ],
      [
        '19',
        'Market Lowest Rate (In Rs. per qtl)',
        _val(bbMod, 'marketLowestRate'),
        _val(bbSplMod, 'marketLowestRate'),
        _val(mech, 'marketLowestRate')
      ],
      [
        '20',
        'CCI Highest Rate (In Rs. per qtl)',
        _val(bbMod, 'cciHighestRate'),
        _val(bbSplMod, 'cciHighestRate'),
        _val(mech, 'cciHighestRate')
      ],
      [
        '21',
        'CCI Lowest Rate (In Rs. per qtl)',
        _val(bbMod, 'cciLowestRate'),
        _val(bbSplMod, 'cciLowestRate'),
        _val(mech, 'cciLowestRate')
      ],
      [
        '22',
        'Prog. Pressed Bales',
        _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPressedBales'),
        _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPressedBales'),
        _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPressedBales')
      ],
      [
        '23',
        'Prog. Purchase in qtls',
        _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPurchaseQtls'),
        _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPurchaseQtls'),
        _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPurchaseQtls')
      ],
      [
        '24',
        'Prog. Purchase Bales',
        _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progPurchaseBales'),
        _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPurchaseBales'),
        _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPurchaseBales')
      ],
      [
        '25',
        'Prog. Kapas Purchased from No. of Farmers  / Prog. No. of Takpatties',
        _progVal(bbMod, bbSplMod, mech, 'BB MOD', 'progFarmers'),
        _progVal(bbMod, bbSplMod, mech, 'BB SPL MOD', 'progFarmers'),
        _progVal(bbMod, bbSplMod, mech, 'MECH', 'progFarmers')
      ],
    ];

    List<Map<String, dynamic>> factories = [];
    final src =
        bbMod?['factories'] ?? bbSplMod?['factories'] ?? mech?['factories'];
    if (src is List) factories = List<Map<String, dynamic>>.from(src);

    return Container(
      decoration:
      BoxDecoration(border: Border.all(color: const Color(0xFF94A3B8))),
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
          _numRow('26', 'Factory wise day purchase details', 'BB MOD',
              'BB SPL MOD', 'MECH',
              bold: true),
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
                _progVal(
                    bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPurchaseQtls'),
                _progVal(
                    bbMod, bbSplMod, mech, 'BB SPL MOD', 'progPurchaseBales'),
                _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPurchaseQtls'),
                _progVal(bbMod, bbSplMod, mech, 'MECH', 'progPurchaseBales'),
              );
            }),
          _totalRow(bbMod, bbSplMod, mech),
        ],
      ),
    );
  }

  // ====================================================================
  // WEIGHT LIST PREVIEW WIDGETS
  // ====================================================================

  Widget _buildWeightListPreviewTable(Map<String, dynamic> data) {
    final dateStr = _fmtDateDisplay(data['date']);
    final centre = (data['centre'] ?? '').toString().toUpperCase();
    final variety = (data['variety'] ?? '').toString();
    final pmNo = (data['pmNo'] ?? '').toString();
    final prNo = (data['prNo'] ?? '').toString();
    final lotNo = (data['lotNo'] ?? '').toString();
    final sampleBaleNo = (data['sampleBaleNo'] ?? '').toString();
    final godown = (data['godown'] ?? '').toString();
    final noOfBales = (data['noOfBales'] ?? 100).toString();
    final moisture = (data['moisture'] ?? '').toString();
    final pressingFactory = (data['pressingFactory'] ?? '').toString();

    // Parse bale entries
    List<Map<String, dynamic>> baleEntries = [];
    final baleSrc = data['baleEntries'];
    if (baleSrc is List) {
      baleEntries = List<Map<String, dynamic>>.from(baleSrc);
    }

    // Summary values
    final tareWeight = _n(data['tareWeight']);
    final totalGrossWeight = _n(data['totalGrossWeight']);
    final totalNettWeight = _n(data['totalNettWeight']);

    String fmt(double v) {
      if (v == v.roundToDouble()) return v.toInt().toString();
      return v.toStringAsFixed(2);
    }

    // Split bales into columns of 10 (matching Excel layout)
    final baleCount = int.tryParse(noOfBales) ?? baleEntries.length;
    final totalBales = baleCount > 0 ? baleCount : baleEntries.length;

    // Build rows for display (5 pairs of NO/Kgs columns per row)
    final rows = <List<Map<String, dynamic>?>>[];
    const balesPerRow = 10; // 5 columns × 2 (NO + Kgs)

    for (int i = 0; i < totalBales; i += balesPerRow) {
      final row = <Map<String, dynamic>?>[];
      for (int j = 0; j < balesPerRow; j++) {
        final idx = i + j;
        if (idx < baleEntries.length) {
          row.add(baleEntries[idx]);
        } else {
          row.add(null);
        }
      }
      rows.add(row);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF94A3B8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Column(
              children: [
                const Text(
                  'THE COTTON CORPORATION OF INDIA LTD',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                const Text(
                  'BRANCH OFFICE :: MAHABUBNAGAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'CENTRE :: $centre',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFF94A3B8)),

          // Info rows
          _weightInfoRow('P.MARK NO: $pmNo', 'P.R.NO: $prNo'),
          _weightInfoRow('VARIETY: $variety', 'Sample Bale No: $sampleBaleNo'),
          _weightInfoRow('LOT NO: $lotNo', 'GODOWN: $godown'),
          _weightInfoRow('NO OF BALES: $noOfBales', 'MOISTURE: $moisture'),
          _weightInfoRow('DATE OF PRESSING: $dateStr', ''),
          _weightInfoRow('NAME OF THE PRESSING FACTORY: $pressingFactory', ''),

          const Divider(height: 1, thickness: 1, color: Color(0xFF94A3B8)),

          // Bale table header
          Container(
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                for (int c = 0; c < 5; c++) ...[
                  _weightHeaderCell('NO'),
                  _weightHeaderCell('Kgs.'),
                ],
              ],
            ),
          ),

          // Bale rows (10 rows per section)
          for (int section = 0; section < rows.length; section += 10) ...[
            // Process in chunks of 10 rows
            for (int r = section;
            r < (section + 10).clamp(0, rows.length);
            r++) ...[
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    for (final bale in rows[r]) ...[
                      _weightDataCell(
                          bale != null ? '${bale['baleNo']}' : ''),
                      _weightDataCell(
                        bale != null ? fmt(_n(bale['weight'])) : '',
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Total row for this section
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
                  for (int c = 0; c < 5; c++) ...[
                    _weightTotalCell(c == 0 ? 'TOTAL' : ''),
                    _weightTotalCell(
                      fmt(
                        _getWeightListColumnTotal(
                          baleEntries,
                          section,
                          c,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Summary section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              children: [
                _weightSummaryRow(
                    'Total Grass Weight :', fmt(totalGrossWeight)),
                _weightSummaryRow('Tare Weight:', fmt(tareWeight)),
                _weightSummaryRow(
                    'Total Nett Weight:', fmt(totalNettWeight)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _getWeightListColumnTotal(
      List<Map<String, dynamic>> baleEntries, int sectionStart, int col) {
    double total = 0;
    for (int r = 0; r < 10; r++) {
      final idx = sectionStart + r + (col * 10);
      if (idx < baleEntries.length) {
        total += _n(baleEntries[idx]['weight']);
      }
    }
    return total;
  }

  Widget _weightInfoRow(String left, String right) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Text(
                left,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Text(
                right,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weightHeaderCell(String text) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
    ),
  );

  Widget _weightDataCell(String text) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Color(0xFF334155),
        ),
      ),
    ),
  );

  Widget _weightTotalCell(String text) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
    ),
  );

  Widget _weightSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // PURCHASE PREVIEW WIDGETS
  // ====================================================================

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
          _cell(b1),
          _cell(b2),
          _cell(b3),
          _cell(b4),
          _cell(b5),
          _cell(b6),
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
          _cell(s('BB MOD', 'progPurchaseBales').toStringAsFixed(0),
              bold: true),
          _cell(s('BB SPL MOD', 'progPurchaseQtls').toStringAsFixed(2),
              bold: true),
          _cell(s('BB SPL MOD', 'progPurchaseBales').toStringAsFixed(0),
              bold: true),
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
    final isWeightList = widget.reportType == 'weightList';
    final availableCentres = _availableCentres;
    final availableVarieties = _availableVarieties;
    final groupedReports = _groupedFilteredReports;

    String appBarTitle;
    if (isPurchase) {
      appBarTitle = 'Purchase Reports';
    } else if (isWeightList) {
      appBarTitle = 'Weight List Reports';
    } else {
      appBarTitle = 'Seed Reports';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
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
                              ...availableVarieties.map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v))),
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
                                  _isDateFilterActive &&
                                      _filterStartDate != null
                                      ? (_filterMode ==
                                      _DateFilterMode.single
                                      ? _formatFilterDate(
                                      _filterStartDate!)
                                      : '${_formatFilterDate(_filterStartDate!)} - ${_formatFilterDate(_filterEndDate!)}')
                                      : (_filterMode ==
                                      _DateFilterMode.single
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
                        : isWeightList
                        ? Icons.scale_outlined
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
                          : isWeightList
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFD1FAE5),
                      child: Icon(
                        isPurchase
                            ? Icons.shopping_basket_rounded
                            : isWeightList
                            ? Icons.scale_rounded
                            : Icons.eco_rounded,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    title: Text(
                      isPurchase
                          ? '$centre - Report #$reportNo'
                          : isWeightList
                          ? 'Weight List - $centre #$reportNo'
                          : (sample['factoryName'] ??
                          centre ??
                          'Report'),
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
                              color: Color(0xFF64748B),
                              fontSize: 13),
                        ),
                        Text(
                          'Centre: $centre',
                          style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13),
                        ),
                        if (isWeightList) ...[
                          Text(
                            'Lot: ${sample['lotNo'] ?? '—'} | Bales: ${sample['noOfBales'] ?? '—'}',
                            style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13),
                          ),
                        ] else ...[
                          Text(
                            'Varieties: ${varieties.join(', ')}',
                            style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13),
                          ),
                        ],
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
              color:
              isClearAll ? Colors.red.shade700 : const Color(0xFF334155),
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