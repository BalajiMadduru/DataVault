import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/apiservice.dart';
import '../models/report_modals.dart';

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

  // Filters
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  _DateFilterMode _filterMode = _DateFilterMode.single;
  String? _selectedCentreFilter;
  String? _selectedVarietyFilter;

  bool get _isDateFilterActive => _filterStartDate != null || _filterEndDate != null;

  bool get _isFilterActive =>
      _isDateFilterActive || _selectedCentreFilter != null || _selectedVarietyFilter != null;

  List<String> get _availableCentres {
    final centres = <String>{};
    for (final report in _reports) {
      final centre = report['centre']?.toString();
      if (centre != null && centre.isNotEmpty) {
        centres.add(centre);
      }
    }
    return centres.toList()..sort();
  }

  List<String> get _availableVarieties {
    if (widget.reportType != 'purchase') return [];
    final varieties = <String>{};
    for (final report in _reports) {
      final variety = report['variety']?.toString();
      if (variety != null && variety.isNotEmpty) {
        varieties.add(variety);
      }
    }
    return varieties.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  // ========================================================================
  // FILTER METHODS
  // ========================================================================

  Future<void> _selectSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _filterStartDate ?? DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
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
    final initialRange = _filterStartDate != null && _filterEndDate != null
        ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!)
        : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
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

  String _formatFilterDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _applyFilters() {
    setState(() {
      _filteredReports = _reports.where((report) {
        final rawDate = report['date']?.toString();
        if (rawDate == null || rawDate.isEmpty) return false;

        final reportDate = DateTime.tryParse(rawDate);
        if (reportDate == null) return false;

        final normalizedReportDate = DateTime(reportDate.year, reportDate.month, reportDate.day);

        if (_filterStartDate != null) {
          final start = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
          if (normalizedReportDate.isBefore(start)) return false;
        }

        if (_filterEndDate != null) {
          final end = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day);
          if (normalizedReportDate.isAfter(end)) return false;
        }

        if (_selectedCentreFilter != null && _selectedCentreFilter!.isNotEmpty) {
          final reportCentre = report['centre']?.toString().toLowerCase() ?? '';
          if (reportCentre != _selectedCentreFilter!.toLowerCase()) return false;
        }

        if (_selectedVarietyFilter != null && _selectedVarietyFilter!.isNotEmpty) {
          final reportVariety = report['variety']?.toString().toLowerCase() ?? '';
          if (reportVariety != _selectedVarietyFilter!.toLowerCase()) return false;
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
          _reports = List<Map<String, dynamic>>.from(response.data!['entries'] ?? []);
        } else {
          _reports = [];
        }
        _isLoading = false;
      });
      _applyFilters();
    }
  }

  // ========================================================================
  // DELETE REPORT METHOD
  // ========================================================================

  Future<void> _deleteReport(Map<String, dynamic> report, int index) async {
    final docId = report['id']?.toString();
    if (docId == null || docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete: Report ID not found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
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
              child: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Report',
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
              'Are you sure you want to delete this report?',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
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
                  Text(
                    'Centre: ${report['centre'] ?? 'Unknown'}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    'Report #${report['reportNo'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Text(
                    'Date: ${report['date']?.toString().split('T').first ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  if (report['variety'] != null)
                    Text(
                      'Variety: ${report['variety']}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  if (report['factoryName'] != null)
                    Text(
                      'Factory: ${report['factoryName']}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      final response = await ApiService.deleteEntry(docId);

      if (!mounted) {
        setState(() => _isDeleting = false);
        return;
      }

      if (response.success) {
        setState(() {
          _reports.removeAt(index);
          _isDeleting = false;
        });
        _applyFilters();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Report deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to delete: ${response.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error deleting report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ========================================================================
  // EXPORT METHODS
  // ========================================================================

  Future<void> _exportPurchaseReports() async {
    if (_filteredReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No reports to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final sortedReports = List<Map<String, dynamic>>.from(_filteredReports)
        ..sort((a, b) {
          final dateA = DateTime.tryParse(a['date']?.toString() ?? '');
          final dateB = DateTime.tryParse(b['date']?.toString() ?? '');
          if (dateA == null || dateB == null) return 0;
          return dateA.compareTo(dateB);
        });

      int successCount = 0;
      int failCount = 0;

      for (int reportIndex = 0; reportIndex < sortedReports.length; reportIndex++) {
        final report = sortedReports[reportIndex];

        try {
          var excel = excel_lib.Excel.createExcel();
          var sheet = excel['Sheet1'];

          void addRow(List<dynamic> cells) {
            sheet.appendRow(cells);
          }

          addRow([]);
          addRow(['', 'THE COTTON CORPORATION OF INDIA LTD :: BRANCH OFFICE HUBLI', '', '', '', '', '', '', '', '', '', '']);
          addRow([]);

          String centre = report['centre']?.toString()?.toUpperCase() ?? 'DEVADURGA';
          String date = report['date']?.toString().split('T').first ?? '';
          String formattedDate = date.replaceAll('-', '.');

          addRow([
            '', '', '',
            'CENTRE:', centre,
            '', '',
            'DATE:', formattedDate,
            '', '', ''
          ]);

          String reportNo = report['reportNo']?.toString() ?? '1';
          addRow([
            'DAILY MARKET/ PURCHASE REPORT NO.',
            '', '', '', '', '', '', '',
            reportNo, '', '', ''
          ]);

          String variety = report['variety']?.toString() ?? 'BB MOD';
          addRow([
            'SL NO', 'PARTICULARS', '', 'VARIETY:', variety, '', '', '', '', '', '', ''
          ]);

          addRow([
            '1', "DAY'S ARRIVALS IN QTLS / BALES", '', 'APMC:',
            report['dayArrivalsApmc']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '', '', '', 'OUTSIDE APMC:',
            report['dayArrivalsOutside']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);

          addRow([
            '2', 'PROG. ARRIVALS IN QTLS / BALES', '', 'APMC:',
            report['progArrivalsApmc']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '', '', '', 'OUTSIDE APMC:',
            report['progArrivalsOutside']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);

          addRow([
            '3', 'MOISTURE PERCENTAGE (%)', '', '',
            report['moisture']?.toString() ?? '8-20%', '', '', '', '', '', '', ''
          ]);

          addRow([
            '4', 'MARKET RATE (KAPAS RATE IN QTLS)', '', 'HIGHEST',
            report['marketRateHighest']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '', '', '', 'LOWEST',
            report['marketRateLowest']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '', '', '', 'AVERAGE',
            report['marketRateAverage']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);

          addRow(['5', 'MARKET OUT TURN', '', '', '-', '', '', '', '', '', '', '']);
          addRow(['6', 'MARKET EXPENSES', '', '', '-', '', '', '', '', '', '', '']);
          addRow(['7', 'MARKET SHORTAGE', '', '', '-', '', '', '', '', '', '', '']);
          addRow(['8', 'MARKET PADTHA', '', '', '-', '', '', '', '', '', '', '']);

          addRow([
            '9', 'MARKET COTTON SEED RATE (PER QTLS)', '', 'HIGHEST',
            report['marketSeedRateHighest']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '', '', '', 'LOWEST',
            report['marketSeedRateLowest']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);

          addRow([
            '10', 'CCI PURCHASE IN', '', 'QTLS',
            report['cciPurchaseQtls']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '', '', '', 'BALES',
            report['cciPurchaseBales']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '', '', '', 'Kapas Mositure %',
            report['cciKapasMoisture']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);

          addRow([
            '11', 'MSP VALUE (IN LAKHS)', '', 'DAY WISE',
            report['mspValueDay']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '', '', '', 'PROGRESSIVE',
            report['mspValueProg']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);

          addRow([
            '12', 'No. OF FARMERS BENEFITTED', '', 'DAY WISE',
            report['farmersDay']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '', '', '', 'PROGRESSIVE',
            report['farmersProgressive']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);

          addRow([
            '13', 'CCI RATE (KAPAS RATE IN QTLS)', '', 'HIGHEST',
            report['cciRateHighest']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '', '', '', 'LOWEST',
            report['cciRateLowest']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '', '', '', 'AVERAGE',
            report['cciRateAverage']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);

          addRow([
            '14', 'CCI COTTON SEED RATE', '', '',
            report['cciSeedRate']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '15', 'CCI OUT TURN', '', '',
            report['cciOutTurn']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '16', 'CCI SHORTAGE', '', '',
            report['cciShortage']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '17', 'CCI EXPENSES', '', '',
            report['cciExpenses']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '18', "PROCESSING CYCLE DAY'S", '', '',
            report['processingCycle']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '19', 'CCI PADTHA', '', '',
            report['cciPadtha']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);

          addRow([
            '20', 'PROGRESSIVE PURCHASE', '', 'QTLS',
            report['progPurchaseQtls']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '', '', '', 'BALES',
            report['progPurchaseBales']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);

          addRow([
            '21', 'PROGRESSIVE', '', 'PADTHA',
            report['progPadtha']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '', '', '', 'AVG. RATE',
            report['progAvgRate']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);

          addRow([
            '22', 'BALES PRESSED DETAILS', '', 'TODAYS',
            report['balesPressedToday']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '', '', '', 'PROGRESSIVE',
            report['balesPressedProg']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);

          addRow([
            '23', 'TOTAL BALES SHIFTED TO GODOWN', '', '',
            report['totalBalesShifted']?.toString() ?? '0', '', '', '', '', '', '', ''
          ]);
          addRow([
            '24', 'SAMPLE SENT TO B.O FOR TESTING', '', '',
            report['sampleSent']?.toString() ?? '-', '', '', '', '', '', '', ''
          ]);
          addRow([
            '25', 'HEAP RESULT SENT TO B.O', '', '',
            report['heapResult']?.toString() ?? '-', '', '', '', '', '', '', ''
          ]);

          final factoriesData = report['factories'];
          List factories = [];
          if (factoriesData is List) {
            factories = factoriesData;
          } else if (factoriesData is Map<String, dynamic>) {
            factories = [factoriesData];
          }

          if (factories.isNotEmpty) {
            addRow([]);
            addRow([]);

            addRow([
              'SL NO', 'NAME OF THE FACTORY', '', '',
              'KAPAS DETAILS', '', 'COTTON SEED SALE DETAILS', '', '', ''
            ]);

            addRow([
              '', '', '', '',
              'HEAP NO.', 'HEAP QTY.', 'FARMERS BENEFITTED',
              'REALISABLE', 'Ready Seed SOLD', 'Ready Seed UNSOLD', 'BASE RATE'
            ]);

            for (int i = 0; i < factories.length; i++) {
              final factory = factories[i] as Map<String, dynamic>;
              addRow([
                (i + 1).toString(),
                factory['factoryName']?.toString() ?? '',
                '', '',
                factory['heapNo']?.toString() ?? '',
                factory['heapQty']?.toString() ?? '',
                factory['seedFarmers']?.toString() ?? '',
                factory['seed_realisable']?.toString() ?? '',
                factory['readySeedSold']?.toString() ?? '',
                factory['readySeedUnsold']?.toString() ?? '',
                factory['baseRate']?.toString() ?? '',
              ]);
            }
          }

          final fileBytes = excel.save();
          if (fileBytes != null) {
            String fileDate = formattedDate.replaceAll('-', '.');
            List<String> dateParts = fileDate.split('.');
            if (dateParts.length == 3) {
              String day = dateParts[0].padLeft(2, '0');
              String month = dateParts[1].padLeft(2, '0');
              String year = dateParts[2].length > 2 ? dateParts[2].substring(2) : dateParts[2];
              fileDate = '$day.$month.$year';
            }

            String fileName = 'DPR $fileDate $centre.xlsx';

            String? savePath;
            if (Platform.isAndroid || Platform.isIOS) {
              final directory = await getExternalStorageDirectory();
              if (directory != null) {
                savePath = '${directory.path}/$fileName';
              }
            } else {
              final directory = await getApplicationDocumentsDirectory();
              savePath = '${directory.path}/$fileName';
            }

            if (savePath != null) {
              final file = File(savePath);
              await file.writeAsBytes(fileBytes);
              successCount++;
            }
          }
        } catch (e) {
          failCount++;
        }
      }

      if (mounted) {
        String message = '✅ Exported $successCount report(s)';
        if (failCount > 0) {
          message += ', $failCount failed';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error exporting reports: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportSeedReports() async {
    if (_filteredReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No reports to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int successCount = 0;
    int failCount = 0;

    for (final report in _filteredReports) {
      try {
        var excel = excel_lib.Excel.createExcel();
        var sheet = excel['Sheet1'];

        void addRow(List<dynamic> cells) {
          sheet.appendRow(cells);
        }

        List<Map<String, dynamic>> factories = [];
        final factoriesData = report['seedFactories'] ?? report['factories'];
        if (factoriesData is List) {
          factories = List<Map<String, dynamic>>.from(factoriesData);
        } else if (factoriesData is Map<String, dynamic>) {
          factories = [factoriesData];
        }

        if (factories.isEmpty) {
          failCount++;
          continue;
        }

        addRow(['THE COTTON CORPORATION OF INDIA LTD :: BRANCH OFFICE HUBLI']);
        addRow([]);

        String centre = report['centre']?.toString()?.toUpperCase() ?? 'DEVADURGA';
        String date = report['date']?.toString().split('T').first ?? '';
        String formattedDate = date.replaceAll('-', '.');
        addRow(['CENTRE:', centre, '', 'DATE:', formattedDate]);
        addRow(['REPORT NO.:', report['reportNo']?.toString() ?? '1']);
        addRow([]);

        addRow([
          'S.No.',
          'Ginning & pressing factory name',
          'Variety',
          'Progressive Realisable (Total)',
          'Progressive Sold',
          "Day's Unsold",
          'Kapas Form',
          'Ready Form',
          'Total',
          'Base Rate'
        ]);

        for (int i = 0; i < factories.length; i++) {
          final factory = factories[i];
          final progressiveRealisable = factory['progressiveRealisable'] ?? 0;
          final progressiveSold = factory['progressiveSold'] ?? 0;
          final dayUnsold = factory['dayUnsold'] ?? 0;
          final kapasForm = factory['kapasForm'] ?? 0;
          final readyForm = factory['readyForm'] ?? 0;
          final total = factory['total'] ?? (kapasForm + readyForm);

          addRow([
            (i + 1).toString(),
            factory['factoryName']?.toString() ?? '',
            factory['variety']?.toString() ?? '',
            progressiveRealisable.toString(),
            progressiveSold.toString(),
            dayUnsold.toString(),
            kapasForm.toString(),
            readyForm.toString(),
            total.toString(),
            factory['baseRate']?.toString() ?? '0',
          ]);
        }

        addRow([]);
        addRow(['Date:', formattedDate]);

        final fileBytes = excel.save();
        if (fileBytes != null) {
          String fileName = 'Seed_Report_$formattedDate.xlsx';
          String? savePath;
          if (Platform.isAndroid || Platform.isIOS) {
            final directory = await getExternalStorageDirectory();
            if (directory != null) {
              savePath = '${directory.path}/$fileName';
            }
          } else {
            final directory = await getApplicationDocumentsDirectory();
            savePath = '${directory.path}/$fileName';
          }

          if (savePath != null) {
            final file = File(savePath);
            await file.writeAsBytes(fileBytes);
            successCount++;
          }
        }
      } catch (e) {
        failCount++;
      }
    }

    if (mounted) {
      String message = '✅ Exported $successCount seed report(s)';
      if (failCount > 0) {
        message += ', $failCount failed';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

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

    final isPurchase = widget.reportType == 'purchase';

    if (isPurchase) {
      await _exportPurchaseReports();
    } else {
      await _exportSeedReports();
    }
  }

  // ========================================================================
  // VIEW REPORT - WITH 3-VARIETY FORMAT
  // ========================================================================

  void _viewReport(Map<String, dynamic> report) {
    final isPurchase = widget.reportType == 'purchase';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(
            maxHeight: 700,
            maxWidth: 1100,
          ),
          padding: const EdgeInsets.all(20),
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
                      color: isPurchase ? const Color(0xFFE0F2FE) : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPurchase ? Icons.shopping_basket_rounded : Icons.eco_rounded,
                      color: const Color(0xFF0F172A),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${isPurchase ? 'Purchase' : 'Seed'} Report - ${report['centre'] ?? 'Unknown'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Report #${report['reportNo'] ?? 'N/A'} | ${report['date']?.toString().split('T').first ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        if (report['variety'] != null)
                          Text(
                            'Variety: ${report['variety']}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Excel-style table with 3 varieties
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 200,
                    maxHeight: 500,
                  ),
                  child: SingleChildScrollView(
                    child: isPurchase
                        ? _buildPurchaseReportView3Variety(report)
                        : _buildSeedReportView(report),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _exportToExcel();
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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

  // ========================================================================
  // 3-VARIETY PURCHASE PREVIEW
  // ========================================================================

  Widget _buildPurchaseReportView3Variety(Map<String, dynamic> report) {
    final currentVariety = report['variety']?.toString() ?? 'BB MOD';

    String getValue(String variety, String field) {
      if (report['variety'] == variety) {
        return report[field]?.toString() ?? '0';
      }
      return '0';
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Company Name
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
              ),
            ),
            child: Text(
              'THE COTTON CORPORATION OF INDIA LTD :: BRANCH OFFICE HUBLI',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Title
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Text(
              'DAILY PURCHASE REPORT',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Header: Centre & Date
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Text('CENTRE:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    (report['centre'] ?? 'DEVADURGA').toString().toUpperCase(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                const Text('DATE:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  _formatDateDisplay(report['date']),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Report No
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Text('DAILY MARKET/ PURCHASE REPORT NO.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const Spacer(),
                Text(
                  report['reportNo']?.toString() ?? '1',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 3-Variety Header
          Row(
            children: [
              const SizedBox(width: 30),
              _buildVarietyHeader('BB MOD', currentVariety == 'BB MOD'),
              const SizedBox(width: 20),
              _buildVarietyHeader('BB SPL MOD', currentVariety == 'BB SPL MOD'),
              const SizedBox(width: 20),
              _buildVarietyHeader('MECH', currentVariety == 'MECH'),
            ],
          ),
          const SizedBox(height: 4),

          // Data Rows
          _buildRowWithThreeValues(
            "Day's Kapas Purchased from No. of Farmers",
            getValue('BB MOD', 'farmersDay'),
            getValue('BB SPL MOD', 'farmersDay'),
            getValue('MECH', 'farmersDay'),
          ),
          _buildRowWithThreeValues(
            'Arrivals (In Bales)',
            getValue('BB MOD', 'arrivalsBales'),
            getValue('BB SPL MOD', 'arrivalsBales'),
            getValue('MECH', 'arrivalsBales'),
          ),
          _buildRowWithThreeValues(
            'CCI Purchases (In Qtls)',
            getValue('BB MOD', 'cciPurchaseQtls'),
            getValue('BB SPL MOD', 'cciPurchaseQtls'),
            getValue('MECH', 'cciPurchaseQtls'),
          ),
          _buildRowWithThreeValues(
            'CCI Purchases (In Bales)',
            getValue('BB MOD', 'cciPurchaseBales'),
            getValue('BB SPL MOD', 'cciPurchaseBales'),
            getValue('MECH', 'cciPurchaseBales'),
          ),
          _buildRowWithThreeValues(
            'Average Kapas rate (In Rs. per qtl)',
            getValue('BB MOD', 'avgKapasRate'),
            getValue('BB SPL MOD', 'avgKapasRate'),
            getValue('MECH', 'avgKapasRate'),
          ),
          _buildRowWithThreeValues(
            'Budgeted Lint Percentage (%)',
            getValue('BB MOD', 'budgetedLint'),
            getValue('BB SPL MOD', 'budgetedLint'),
            getValue('MECH', 'budgetedLint'),
          ),
          _buildRowWithThreeValues(
            'Budgeted Shortage Percentage (%)',
            getValue('BB MOD', 'budgetedShortage'),
            getValue('BB SPL MOD', 'budgetedShortage'),
            getValue('MECH', 'budgetedShortage'),
          ),
          _buildRowWithThreeValues(
            'Cotton seed rate (In Rs. per qtl)',
            getValue('BB MOD', 'cottonSeedRate'),
            getValue('BB SPL MOD', 'cottonSeedRate'),
            getValue('MECH', 'cottonSeedRate'),
          ),
          _buildRowWithThreeValues(
            "Processing cycle (In day's)",
            getValue('BB MOD', 'processingCycle'),
            getValue('BB SPL MOD', 'processingCycle'),
            getValue('MECH', 'processingCycle'),
          ),
          _buildRowWithThreeValues(
            'Proforma Expenses (In Rs. per Candy)',
            getValue('BB MOD', 'proformaExpenses'),
            getValue('BB SPL MOD', 'proformaExpenses'),
            getValue('MECH', 'proformaExpenses'),
          ),
          _buildRowWithThreeValues(
            'Budgeted Padtha (In Rs. per candy)',
            getValue('BB MOD', 'budgetedPadtha'),
            getValue('BB SPL MOD', 'budgetedPadtha'),
            getValue('MECH', 'budgetedPadtha'),
          ),
          _buildRowWithThreeValues(
            "Day's pressed bales (In Bales)",
            getValue('BB MOD', 'dayPressedBales'),
            getValue('BB SPL MOD', 'dayPressedBales'),
            getValue('MECH', 'dayPressedBales'),
          ),
          const SizedBox(height: 6),

          // Market & CCI Rates
          const Divider(thickness: 1),
          const Text(
            'MARKET & CCI RATES',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          _buildRowWithThreeValues(
            'Market Highest Rate (In Rs. per qtl)',
            getValue('BB MOD', 'marketHighestRate'),
            getValue('BB SPL MOD', 'marketHighestRate'),
            getValue('MECH', 'marketHighestRate'),
          ),
          _buildRowWithThreeValues(
            'Market Lowest Rate (In Rs. per qtl)',
            getValue('BB MOD', 'marketLowestRate'),
            getValue('BB SPL MOD', 'marketLowestRate'),
            getValue('MECH', 'marketLowestRate'),
          ),
          _buildRowWithThreeValues(
            'CCI Highest Rate (In Rs. per qtl)',
            getValue('BB MOD', 'cciHighestRate'),
            getValue('BB SPL MOD', 'cciHighestRate'),
            getValue('MECH', 'cciHighestRate'),
          ),
          _buildRowWithThreeValues(
            'CCI Lowest Rate (In Rs. per qtl)',
            getValue('BB MOD', 'cciLowestRate'),
            getValue('BB SPL MOD', 'cciLowestRate'),
            getValue('MECH', 'cciLowestRate'),
          ),
          const SizedBox(height: 6),

          // Progressive Values
          const Divider(thickness: 1),
          const Text(
            'PROGRESSIVE VALUES',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          _buildRowWithThreeValues(
            'Prog. Pressed Bales',
            getValue('BB MOD', 'progPressedBales'),
            getValue('BB SPL MOD', 'progPressedBales'),
            getValue('MECH', 'progPressedBales'),
          ),
          _buildRowWithThreeValues(
            'Prog. Purchase (Qtls)',
            getValue('BB MOD', 'progPurchaseQtls'),
            getValue('BB SPL MOD', 'progPurchaseQtls'),
            getValue('MECH', 'progPurchaseQtls'),
          ),
          _buildRowWithThreeValues(
            'Prog. Purchase (Bales)',
            getValue('BB MOD', 'progPurchaseBales'),
            getValue('BB SPL MOD', 'progPurchaseBales'),
            getValue('MECH', 'progPurchaseBales'),
          ),
          _buildRowWithThreeValues(
            'Prog. Kapas Purchased from No. of Farmers',
            getValue('BB MOD', 'progFarmers'),
            getValue('BB SPL MOD', 'progFarmers'),
            getValue('MECH', 'progFarmers'),
          ),
          const SizedBox(height: 6),

          // Factory Details
          const Divider(thickness: 1),
          const Text(
            'FACTORY WISE DAY PURCHASE DETAILS',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          _buildFactoryTable3Variety(report),
        ],
      ),
    );
  }

  Widget _buildVarietyHeader(String title, bool isActive) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildRowWithThreeValues(String label, String v1, String v2, String v3) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 230,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              v2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              v3,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // FACTORY TABLE - 3 VARIETY (FIXED)
  // ========================================================================

  Widget _buildFactoryTable3Variety(Map<String, dynamic> report) {
    List<Map<String, dynamic>> factories = [];
    final factoriesData = report['factories'];
    if (factoriesData is List) {
      factories = List<Map<String, dynamic>>.from(factoriesData);
    }

    if (factories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: Text(
            'No factory data available',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ),
      );
    }

    final currentVariety = report['variety']?.toString() ?? 'BB MOD';

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row - FIXED: No width: double.infinity
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 30, child: Text('SNO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10))),
                  const SizedBox(width: 150, child: Text('Factory Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10))),
                  const SizedBox(width: 20),
                  _buildTableHeader3('BB MOD', currentVariety == 'BB MOD'),
                  const SizedBox(width: 10),
                  _buildTableHeader3('BB SPL MOD', currentVariety == 'BB SPL MOD'),
                  const SizedBox(width: 10),
                  _buildTableHeader3('MECH', currentVariety == 'MECH'),
                ],
              ),
            ),
            // Data Rows
            ...factories.asMap().entries.map((entry) {
              final index = entry.key;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                decoration: BoxDecoration(
                  color: index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 30, child: Text('${index + 1}', style: const TextStyle(fontSize: 10))),
                    SizedBox(
                      width: 150,
                      child: Text(
                        factories[index]['factoryName']?.toString() ?? '',
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 20),
                    _buildFactoryValueCell3(report, 'BB MOD', index),
                    const SizedBox(width: 10),
                    _buildFactoryValueCell3(report, 'BB SPL MOD', index),
                    const SizedBox(width: 10),
                    _buildFactoryValueCell3(report, 'MECH', index),
                  ],
                ),
              );
            }),
            // Total Row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                border: Border(
                  top: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 30),
                  const SizedBox(
                    width: 150,
                    child: Text(
                      'TOTAL',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  _buildTotalCell3(report, 'BB MOD'),
                  const SizedBox(width: 10),
                  _buildTotalCell3(report, 'BB SPL MOD'),
                  const SizedBox(width: 10),
                  _buildTotalCell3(report, 'MECH'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader3(String title, bool isActive) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            'Prog Pur\n(Qtls)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 8,
              color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 70,
          child: Text(
            'Prog Pur\n(Bales)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 8,
              color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFactoryValueCell3(Map<String, dynamic> report, String targetVariety, int factoryIndex) {
    if (report['variety'] != targetVariety) {
      return Row(
        children: [
          SizedBox(width: 70, child: const Text('', textAlign: TextAlign.center)),
          const SizedBox(width: 4),
          SizedBox(width: 70, child: const Text('', textAlign: TextAlign.center)),
        ],
      );
    }

    final factories = report['factories'];
    if (factories is! List || factoryIndex >= factories.length) {
      return Row(
        children: [
          SizedBox(width: 70, child: const Text('', textAlign: TextAlign.center)),
          const SizedBox(width: 4),
          SizedBox(width: 70, child: const Text('', textAlign: TextAlign.center)),
        ],
      );
    }

    final factory = factories[factoryIndex];
    if (factory is! Map) {
      return Row(
        children: [
          SizedBox(width: 70, child: const Text('', textAlign: TextAlign.center)),
          const SizedBox(width: 4),
          SizedBox(width: 70, child: const Text('', textAlign: TextAlign.center)),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            factory['progPurchaseQtls']?.toString() ?? '0',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 70,
          child: Text(
            factory['progPurchaseBales']?.toString() ?? '0',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalCell3(Map<String, dynamic> report, String targetVariety) {
    if (report['variety'] != targetVariety) {
      return Row(
        children: [
          SizedBox(width: 70, child: const Text('', textAlign: TextAlign.center)),
          const SizedBox(width: 4),
          SizedBox(width: 70, child: const Text('', textAlign: TextAlign.center)),
        ],
      );
    }

    final factories = report['factories'];
    if (factories is! List) {
      return Row(
        children: [
          SizedBox(width: 70, child: const Text('', textAlign: TextAlign.center)),
          const SizedBox(width: 4),
          SizedBox(width: 70, child: const Text('', textAlign: TextAlign.center)),
        ],
      );
    }

    double totalQtls = 0;
    double totalBales = 0;
    for (final factory in factories) {
      if (factory is Map) {
        totalQtls += (factory['progPurchaseQtls'] as num?)?.toDouble() ?? 0;
        totalBales += (factory['progPurchaseBales'] as num?)?.toDouble() ?? 0;
      }
    }

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            totalQtls.toStringAsFixed(2),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 70,
          child: Text(
            totalBales.toStringAsFixed(0),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateDisplay(dynamic dateValue) {
    if (dateValue == null) return '';
    try {
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return '';
      }
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day.$month.$year';
    } catch (e) {
      return '';
    }
  }

  // ========================================================================
  // SEED REPORT VIEW
  // ========================================================================

  Widget _buildSeedReportView(Map<String, dynamic> report) {
    List<Map<String, dynamic>> factories = [];
    final factoriesData = report['seedFactories'] ?? report['factories'];
    if (factoriesData is List) {
      factories = List<Map<String, dynamic>>.from(factoriesData);
    } else if (factoriesData is Map<String, dynamic>) {
      factories = [factoriesData];
    }

    if (factories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No factory data available',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Text('CENTRE:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    (report['centre'] ?? 'DEVADURGA').toString().toUpperCase(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                const Text('DATE:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  _formatDateDisplay(report['date']),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Text('REPORT NO.:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  report['reportNo']?.toString() ?? '1',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              border: Border(
                top: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              children: [
                SizedBox(width: 35, child: _buildTableHeader('S.No.')),
                SizedBox(width: 160, child: _buildTableHeader('Ginning & pressing factory name')),
                SizedBox(width: 70, child: _buildTableHeader('Variety')),
                SizedBox(width: 80, child: _buildTableHeader('Progressive Realisable (Total)')),
                SizedBox(width: 70, child: _buildTableHeader('Progressive Sold')),
                SizedBox(width: 65, child: _buildTableHeader("Day's Unsold")),
                SizedBox(width: 60, child: _buildTableHeader('Kapas Form')),
                SizedBox(width: 60, child: _buildTableHeader('Ready Form')),
                SizedBox(width: 50, child: _buildTableHeader('Total')),
                SizedBox(width: 60, child: _buildTableHeader('Base Rate')),
              ],
            ),
          ),
          ...factories.asMap().entries.map((entry) {
            final index = entry.key;
            final factory = entry.value;
            final total = factory['total'] ??
                (factory['kapasForm'] ?? 0) + (factory['readyForm'] ?? 0);
            return Container(
              decoration: BoxDecoration(
                color: index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
              child: Row(
                children: [
                  SizedBox(width: 35, child: Text('${index + 1}', style: const TextStyle(fontSize: 10))),
                  SizedBox(
                    width: 160,
                    child: Text(
                      factory['factoryName']?.toString() ?? '',
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 70, child: Text(factory['variety']?.toString() ?? '', style: const TextStyle(fontSize: 10))),
                  SizedBox(width: 80, child: Text(factory['progressiveRealisable']?.toString() ?? '0', style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                  SizedBox(width: 70, child: Text(factory['progressiveSold']?.toString() ?? '0', style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                  SizedBox(width: 65, child: Text(factory['dayUnsold']?.toString() ?? '0', style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                  SizedBox(width: 60, child: Text(factory['kapasForm']?.toString() ?? '0', style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                  SizedBox(width: 60, child: Text(factory['readyForm']?.toString() ?? '0', style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                  SizedBox(width: 50, child: Text(
                    total.toString(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right,
                  )),
                  SizedBox(width: 60, child: Text(factory['baseRate']?.toString() ?? '0', style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 9,
        color: Color(0xFF0F172A),
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  // ========================================================================
  // BUILD
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    final isPurchase = widget.reportType == 'purchase';
    final availableCentres = _availableCentres;
    final availableVarieties = _availableVarieties;

    return Scaffold(
      appBar: AppBar(
        title: Text('${isPurchase ? 'Purchase' : 'Seed'} Reports'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
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
          // Filter Bar
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
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
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
                            ...availableCentres.map((centre) {
                              return DropdownMenuItem<String>(
                                value: centre,
                                child: Text(centre),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedCentreFilter = value;
                            });
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
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
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
                              ...availableVarieties.map((variety) {
                                return DropdownMenuItem<String>(
                                  value: variety,
                                  child: Text(variety),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedVarietyFilter = value;
                              });
                              _applyFilters();
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Date Picker
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _openDatePicker,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        tooltip: 'Clear date filter',
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
          // List
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
              ),
            )
                : _filteredReports.isEmpty
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
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isFilterActive
                        ? 'Try changing your filters'
                        : 'Use the filters above to find reports',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    textAlign: TextAlign.center,
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
              itemCount: _filteredReports.length,
              itemBuilder: (context, index) {
                final report = _filteredReports[index];
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
                          ? '${report['centre'] ?? 'Unknown'} - Report #${report['reportNo'] ?? 'N/A'}'
                          : (report['factoryName'] ?? report['centre'] ?? 'Report'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Date: ${report['date']?.toString().split('T').first ?? 'N/A'}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Centre: ${report['centre'] ?? 'Unknown'}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                        if (isPurchase) ...[
                          if (report['variety'] != null)
                            Text(
                              'Variety: ${report['variety']}',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            'Amount: ₹${report['mspValueDay'] ?? 0} | Farmers: ${report['farmersDay'] ?? 0}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Quintals: ${report['cciPurchaseQtls'] ?? 0} | Bales: ${report['cciPurchaseBales'] ?? 0}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ] else ...[
                          if (report['variety'] != null)
                            Text(
                              'Variety: ${report['variety']}',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            'Heap Qty: ${report['heapQty'] ?? 0} Quintals | Base Rate: ₹${report['baseRate'] ?? 0}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Farmers: ${report['seedFarmers'] ?? 0}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility),
                          onPressed: () => _viewReport(report),
                          tooltip: 'View Details',
                        ),
                        IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: _exportToExcel,
                          tooltip: 'Export',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.red.shade400,
                          ),
                          onPressed: _isDeleting ? null : () => _deleteReport(report, index),
                          tooltip: 'Delete Report',
                        ),
                      ],
                    ),
                    onTap: () => _viewReport(report),
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
              color: isClearAll ? Colors.red.shade700 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}