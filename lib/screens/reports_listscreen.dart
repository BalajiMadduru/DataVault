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

  bool get _isFilterActive => _filterStartDate != null || _filterEndDate != null || _selectedCentreFilter != null;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

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

  String _formatFilterDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _applyFilters() {
    setState(() {
      _filteredReports = _reports.where((report) {
        // Date filter
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

        // Centre filter
        if (_selectedCentreFilter != null && _selectedCentreFilter!.isNotEmpty) {
          final reportCentre = report['centre']?.toString().toLowerCase() ?? '';
          if (reportCentre != _selectedCentreFilter!.toLowerCase()) return false;
        }

        return true;
      }).toList();
    });
  }

  void _clearCentreFilter() {
    setState(() {
      _selectedCentreFilter = null;
    });
    _applyFilters();
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

    // Show confirmation dialog
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
        // Remove the report from the list
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

          // Row 1: Empty
          addRow([]);

          // Row 2: Company Name
          addRow(['', 'THE COTTON CORPORATION OF INDIA LTD :: BRANCH OFFICE HUBLI', '', '', '', '', '', '', '', '', '', '']);

          // Row 3: Empty
          addRow([]);

          // Row 4: CENTRE and DATE
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

          // Row 5: Report No
          String reportNo = report['reportNo']?.toString() ?? '1';
          addRow([
            'DAILY MARKET/ PURCHASE REPORT NO.',
            '', '', '', '', '', '', '',
            reportNo, '', '', ''
          ]);

          // Row 6: Variety
          String variety = report['variety']?.toString() ?? 'BB MOD';
          addRow([
            'SL NO', 'PARTICULARS', '', 'VARIETY:', variety, '', '', '', '', '', '', ''
          ]);

          // Data Rows
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

          // Factory Details
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
                factory['realisable']?.toString() ?? '',
                factory['readySeedSold']?.toString() ?? '',
                factory['readySeedUnsold']?.toString() ?? '',
                factory['baseRate']?.toString() ?? '',
              ]);
            }
          }

          // Save Individual File
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

        // Get factories data
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

        // Company Name
        addRow(['THE COTTON CORPORATION OF INDIA LTD :: BRANCH OFFICE HUBLI']);
        addRow([]);

        // Centre and Date
        String centre = report['centre']?.toString()?.toUpperCase() ?? 'DEVADURGA';
        String date = report['date']?.toString().split('T').first ?? '';
        String formattedDate = date.replaceAll('-', '.');
        addRow(['CENTRE:', centre, '', 'DATE:', formattedDate]);
        addRow(['REPORT NO.:', report['reportNo']?.toString() ?? '1']);
        addRow([]);

        // Table Header
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

        // Data Rows
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
          constraints: const BoxConstraints(maxHeight: 700, maxWidth: 900),
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
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Excel-style table
              Expanded(
                child: SingleChildScrollView(
                  child: isPurchase
                      ? _buildPurchaseReportView(report)
                      : _buildSeedReportView(report),
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

  Widget _buildPurchaseReportView(Map<String, dynamic> report) {
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
            width: double.infinity,
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

          // Centre & Date
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
                    ),
                  ),
                  padding: const EdgeInsets.only(right: 8),
                  child: const Text('CENTRE:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    (report['centre'] ?? 'DEVADURGA').toString().toUpperCase(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: const Text('DATE:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ),
                const SizedBox(width: 4),
                Text(
                  report['date']?.toString().split('T').first.replaceAll('-', '.') ?? '',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Report No & Variety
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
                    ),
                  ),
                  padding: const EdgeInsets.only(right: 8),
                  child: const Text('DAILY MARKET/ PURCHASE REPORT NO.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ),
                const Spacer(),
                Text(
                  report['reportNo']?.toString() ?? '1',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // SL NO | PARTICULARS | VARIETY
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              border: Border(
                top: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
                    ),
                  ),
                  child: const Text(
                    'SL NO',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: const Text(
                      'PARTICULARS',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'VARIETY:',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    report['variety']?.toString() ?? 'BB MOD',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Data rows
          _buildReportRow('1', "DAY'S ARRIVALS IN QTLS / BALES", 'APMC:', report['dayArrivalsApmc']?.toString() ?? '0'),
          _buildReportRow('', '', 'OUTSIDE APMC:', report['dayArrivalsOutside']?.toString() ?? '0'),
          _buildReportRow('2', 'PROG. ARRIVALS IN QTLS / BALES', 'APMC:', report['progArrivalsApmc']?.toString() ?? '0'),
          _buildReportRow('', '', 'OUTSIDE APMC:', report['progArrivalsOutside']?.toString() ?? '0'),
          _buildReportRow('3', 'MOISTURE PERCENTAGE (%)', '', report['moisture']?.toString() ?? '8-20%'),
          _buildReportRow('4', 'MARKET RATE (KAPAS RATE IN QTLS)', 'HIGHEST', report['marketRateHighest']?.toString() ?? '0'),
          _buildReportRow('', '', 'LOWEST', report['marketRateLowest']?.toString() ?? '0'),
          _buildReportRow('', '', 'AVERAGE', report['marketRateAverage']?.toString() ?? '0'),
          _buildReportRow('5', 'MARKET OUT TURN', '', '-'),
          _buildReportRow('6', 'MARKET EXPENSES', '', '-'),
          _buildReportRow('7', 'MARKET SHORTAGE', '', '-'),
          _buildReportRow('8', 'MARKET PADTHA', '', '-'),
          _buildReportRow('9', 'MARKET COTTON SEED RATE (PER QTLS)', 'HIGHEST', report['marketSeedRateHighest']?.toString() ?? '0'),
          _buildReportRow('', '', 'LOWEST', report['marketSeedRateLowest']?.toString() ?? '0'),
          _buildReportRow('10', 'CCI PURCHASE IN', 'QTLS', report['cciPurchaseQtls']?.toString() ?? '0'),
          _buildReportRow('', '', 'BALES', report['cciPurchaseBales']?.toString() ?? '0'),
          _buildReportRow('', '', 'Kapas Mositure %', report['cciKapasMoisture']?.toString() ?? '0'),
          _buildReportRow('11', 'MSP VALUE (IN LAKHS)', 'DAY WISE', report['mspValueDay']?.toString() ?? '0'),
          _buildReportRow('', '', 'PROGRESSIVE', report['mspValueProg']?.toString() ?? '0'),
          _buildReportRow('12', 'No. OF FARMERS BENEFITTED', 'DAY WISE', report['farmersDay']?.toString() ?? '0'),
          _buildReportRow('', '', 'PROGRESSIVE', report['farmersProgressive']?.toString() ?? '0'),
          _buildReportRow('13', 'CCI RATE (KAPAS RATE IN QTLS)', 'HIGHEST', report['cciRateHighest']?.toString() ?? '0'),
          _buildReportRow('', '', 'LOWEST', report['cciRateLowest']?.toString() ?? '0'),
          _buildReportRow('', '', 'AVERAGE', report['cciRateAverage']?.toString() ?? '0'),
          _buildReportRow('14', 'CCI COTTON SEED RATE', '', report['cciSeedRate']?.toString() ?? '0'),
          _buildReportRow('15', 'CCI OUT TURN', '', report['cciOutTurn']?.toString() ?? '0'),
          _buildReportRow('16', 'CCI SHORTAGE', '', report['cciShortage']?.toString() ?? '0'),
          _buildReportRow('17', 'CCI EXPENSES', '', report['cciExpenses']?.toString() ?? '0'),
          _buildReportRow('18', "PROCESSING CYCLE DAY'S", '', report['processingCycle']?.toString() ?? '0'),
          _buildReportRow('19', 'CCI PADTHA', '', report['cciPadtha']?.toString() ?? '0'),
          _buildReportRow('20', 'PROGRESSIVE PURCHASE', 'QTLS', report['progPurchaseQtls']?.toString() ?? '0'),
          _buildReportRow('', '', 'BALES', report['progPurchaseBales']?.toString() ?? '0'),
          _buildReportRow('21', 'PROGRESSIVE', 'PADTHA', report['progPadtha']?.toString() ?? '0'),
          _buildReportRow('', '', 'AVG. RATE', report['progAvgRate']?.toString() ?? '0'),
          _buildReportRow('22', 'BALES PRESSED DETAILS', 'TODAYS', report['balesPressedToday']?.toString() ?? '0'),
          _buildReportRow('', '', 'PROGRESSIVE', report['balesPressedProg']?.toString() ?? '0'),
          _buildReportRow('23', 'TOTAL BALES SHIFTED TO GODOWN', '', report['totalBalesShifted']?.toString() ?? '0'),
          _buildReportRow('24', 'SAMPLE SENT TO B.O FOR TESTING', '', report['sampleSent']?.toString() ?? '-'),
          _buildReportRow('25', 'HEAP RESULT SENT TO B.O', '', report['heapResult']?.toString() ?? '-'),

          _buildFactoryDetails(report),
        ],
      ),
    );
  }

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
          // Header
          Container(
            width: double.infinity,
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

          // Centre & Date
          Container(
            width: double.infinity,
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
                  report['date']?.toString().split('T').first.replaceAll('-', '.') ?? '',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Report No
          Container(
            width: double.infinity,
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

          // Table Header
          Container(
            width: double.infinity,
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

          // Data Rows
          ...factories.asMap().entries.map((entry) {
            final index = entry.key;
            final factory = entry.value;
            final total = factory['total'] ??
                (factory['kapasForm'] ?? 0) + (factory['readyForm'] ?? 0);
            return Container(
              width: double.infinity,
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

  Widget _buildReportRow(String slNo, String particulars, String subLabel, String value) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: slNo.isNotEmpty ? const Color(0xFFF8FAFC) : Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
              ),
            ),
            child: Text(
              slNo,
              style: TextStyle(
                fontWeight: slNo.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                fontSize: 11,
                color: slNo.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                particulars,
                style: TextStyle(
                  fontWeight: slNo.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 11,
                  color: slNo.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          if (subLabel.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: const Color(0xFFE2E8F0), width: 0.5),
                  right: BorderSide(color: const Color(0xFFE2E8F0), width: 0.5),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                subLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactoryDetails(Map<String, dynamic> report) {
    final factoriesData = report['factories'];

    List factories = [];
    if (factoriesData is List) {
      factories = factoriesData;
    } else if (factoriesData is Map<String, dynamic>) {
      factories = [factoriesData];
    }

    if (factories.isEmpty) {
      return const SizedBox.shrink();
    }

    List<Widget> children = [
      const Divider(height: 16, thickness: 1),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
        ),
        child: const Text(
          'FACTORY DETAILS',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ),
      Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFE2E8F0),
          border: Border(
            top: BorderSide(color: Color(0xFFCBD5E1), width: 1),
            bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 30,
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
                ),
              ),
              child: const Text('SL NO',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: const Text('FACTORY NAME',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 35,
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
                ),
              ),
              child: const Text('HEAP NO.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 35,
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
                ),
              ),
              child: const Text('HEAP QTY.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 35,
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
                ),
              ),
              child: const Text('FARMERS',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 30,
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
                ),
              ),
              child: const Text('REAL.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 30,
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
                ),
              ),
              child: const Text('SOLD',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 30,
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
                ),
              ),
              child: const Text('UNSOLD',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 35,
              child: const Text('BASE RATE',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ];

    for (int i = 0; i < factories.length; i++) {
      final factory = factories[i] as Map<String, dynamic>;
      children.add(
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
            border: const Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 30,
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                  ),
                ),
                child: Text((i + 1).toString(),
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(factory['factoryName']?.toString() ?? '',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 35,
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                  ),
                ),
                child: Text(factory['heapNo']?.toString() ?? '',
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 35,
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                  ),
                ),
                child: Text(factory['heapQty']?.toString() ?? '',
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 35,
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                  ),
                ),
                child: Text(factory['seedFarmers']?.toString() ?? '',
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 30,
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                  ),
                ),
                child: Text(factory['realisable']?.toString() ?? '',
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 30,
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                  ),
                ),
                child: Text(factory['readySeedSold']?.toString() ?? '',
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 30,
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                  ),
                ),
                child: Text(factory['readySeedUnsold']?.toString() ?? '',
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 35,
                child: Text(factory['baseRate']?.toString() ?? '',
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    children.add(
      Container(
        height: 1,
        color: const Color(0xFFCBD5E1),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPurchase = widget.reportType == 'purchase';

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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter Mode Chips
                Row(
                  children: [
                    _ModeChip(
                      label: 'Single Date',
                      selected: _filterMode == _DateFilterMode.single,
                      onTap: () => _setFilterMode(_DateFilterMode.single),
                    ),
                    const SizedBox(width: 8),
                    _ModeChip(
                      label: 'Date Range',
                      selected: _filterMode == _DateFilterMode.range,
                      onTap: () => _setFilterMode(_DateFilterMode.range),
                    ),
                    const SizedBox(width: 8),
                    // Centre Filter Dropdown
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
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
                            ...ReportConstants.centres.map((centre) {
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
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                              color: _isFilterActive
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: _isFilterActive
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _isFilterActive && _filterStartDate != null
                                      ? (_filterMode == _DateFilterMode.single
                                      ? _formatFilterDate(_filterStartDate!)
                                      : '${_formatFilterDate(_filterStartDate!)} - ${_formatFilterDate(_filterEndDate!)}')
                                      : (_filterMode == _DateFilterMode.single
                                      ? 'Select date'
                                      : 'Select date range'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _isFilterActive
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
                    if (_isFilterActive) ...[
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
              ],
            ),
          ),
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
                        : 'Select a date to view reports',
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
                        : 'Choose a date above to see reports',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_isFilterActive) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        _clearDateFilter();
                        _clearCentreFilter();
                      },
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
                          : report['factoryName'] ?? 'Report',
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
                        if (isPurchase) ...[
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