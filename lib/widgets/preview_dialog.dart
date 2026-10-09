import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../enums/report_type.dart';
import '../services/ExportHelper.java';

class PreviewDialog extends StatelessWidget {
  final ReportType type;
  final Map<String, dynamic>? data;

  /// When provided and `type == ReportType.weightList`, the dialog renders
  /// every entry in this list as a full weight-list report, one after
  /// another (stacked). Used by the grouped weight-list cards.
  final List<Map<String, dynamic>>? groupData;

  const PreviewDialog({
    super.key,
    required this.type,
    this.data,
    this.groupData,
  });

  static const List<String> _varieties = ['BB MOD', 'BB SPL MOD', 'MECH'];

  bool get _isGroupedWeightList =>
      type == ReportType.weightList &&
          groupData != null &&
          groupData!.isNotEmpty;

  String _v(Map<String, dynamic>? doc, String targetVariety, String field) {
    if (doc == null) return '0';
    final ownVariety = (doc['variety'] ?? '').toString();
    if (ownVariety == targetVariety) {
      final v = doc[field];
      return v?.toString() ?? '0';
    }
    final others = doc['otherVarietiesProgressive'];
    if (others is Map) {
      final other = others[targetVariety];
      if (other is Map) {
        final v = other[field];
        return v?.toString() ?? '0';
      }
    }
    return '0';
  }

  String _formatDate(dynamic dateValue) {
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

  String _fq(dynamic v) {
    if (v == null) return '0';
    final d = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toStringAsFixed(2);
  }

  String get _title {
    if (_isGroupedWeightList) return 'Weight List Preview';
    switch (type) {
      case ReportType.dailyPurchase:
        return 'Purchase Report Preview';
      case ReportType.dailySeed:
        return 'Seed Report Preview';
      case ReportType.weightList:
        return 'Weight List Preview';
    }
  }

  IconData get _icon {
    switch (type) {
      case ReportType.dailyPurchase:
        return Icons.shopping_basket_rounded;
      case ReportType.dailySeed:
        return Icons.eco_rounded;
      case ReportType.weightList:
        return Icons.scale_rounded;
    }
  }

  Color get _headerColor {
    switch (type) {
      case ReportType.dailyPurchase:
        return const Color(0xFFE0F2FE);
      case ReportType.dailySeed:
        return const Color(0xFFD1FAE5);
      case ReportType.weightList:
        return const Color(0xFFFEF3C7);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _headerColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                  Icon(_icon, color: const Color(0xFF0F172A), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  child: _buildBody(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 8),
                // ⭐ NEW: PDF export button
                ElevatedButton.icon(
                  onPressed: (data == null && groupData == null)
                      ? null
                      : () => _exportPdf(context),
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Export PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: (data == null && groupData == null)
                      ? null
                      : () => _export(context),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
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
    );
  }

  Widget _buildBody() {
    if (_isGroupedWeightList) {
      return _buildGroupedWeightListPreview();
    }
    switch (type) {
      case ReportType.dailyPurchase:
        return _buildPurchasePreview(data);
      case ReportType.dailySeed:
        return _buildSeedPreview(data);
      case ReportType.weightList:
        return _buildWeightListPreview(data);
    }
  }

  // ============================================================
  // PURCHASE
  // ============================================================

  // (label, field) pairs for the main block. Numbering starts at 4
  // (1 = date, 2 = centre, 3 = variety) and the factory section follows.
  static const List<List<String>> _purchaseRowDefs = [
    ["Day's Kapas Purchased from No. of Farmers / No. of Takpatties", 'farmersDay'],
    ['Arrivals (In Bales)', 'arrivalsBales'],
    ['CCI Purchases (In Qtls)', 'cciPurchaseQtls'],
    ['CCI Purchases (In Bales)', 'cciPurchaseBales'],
    ['Avarage Kapas rate (In Rs. per qtl)', 'avgKapasRate'],
    ['Budgeted Lint Percetage (%)', 'budgetedLint'],
    ['Budgeted Shortage Percetage (%)', 'budgetedShortage'],
    ['Cotton seed Percetage (%)', 'budgetedCottonSeedPct'],
    ['Cotton seed rate  (In Rs. per qtl)', 'cottonSeedRate'],
    ["Processing cycle (In day's)", 'processingCycle'],
    ['Proforma Expenses (In Rs. per Candy)', 'proformaExpenses'],
    ['Budgeted Padtha (In Rs. per candy)', 'budgetedPadtha'],
    ["Day's pressed bales (In Bales)", 'dayPressedBales'],
    ['Market Highest Rate (In Rs. per qtl)', 'marketHighestRate'],
    ['Market Lowest Rate (In Rs. per qtl)', 'marketLowestRate'],
    ['CCI Highest Rate (In Rs. per qtl)', 'cciHighestRate'],
    ['CCI Lowest Rate (In Rs. per qtl)', 'cciLowestRate'],
    ['Prog. Pressed Bales', 'progPressedBales'],
    ['Prog. Purchase in qtls', 'progPurchaseQtls'],
    ['Prog. Purchase Bales', 'progPurchaseBales'],
    ['Prog. Kapas Purchased from No. of Farmers  / Prog. No. of Takpatties', 'progFarmers'],
  ];

  static const List<String> _factoryKeys = [
    'todayQtls',
    'todayBales',
    'qtls',
    'bales',
  ];

  static const List<String> _factorySubHeaders = [
    'Today Pur.\nin qtls',
    'Today Pur.\nin Bales',
    'Prog. Pur.\nin qtls',
    'Prog. Pur.\nin Bales',
  ];

  /// Serial number of the "Factory wise day purchase details" row.
  int get _factoryRowNo => 4 + _purchaseRowDefs.length;

  /// [sno, label, BB MOD, BB SPL MOD, MECH]
  List<List<String>> _purchaseRows(Map<String, dynamic>? data) {
    return [
      for (int i = 0; i < _purchaseRowDefs.length; i++)
        [
          '${i + 4}',
          _purchaseRowDefs[i][0],
          _v(data, 'BB MOD', _purchaseRowDefs[i][1]),
          _v(data, 'BB SPL MOD', _purchaseRowDefs[i][1]),
          _v(data, 'MECH', _purchaseRowDefs[i][1]),
        ],
    ];
  }

  /// Factory table rows: [sno, name, then 12 values (3 varieties x 4)].
  /// Always at least 3 rows (blank-padded), like the Excel template.
  List<List<String>> _factoryTableRows(Map<String, dynamic>? data) {
    final matrix = _buildFactoryMatrix(data);
    final names = matrix.keys.toList()..sort();
    final rows = <List<String>>[];
    for (int i = 0; i < names.length; i++) {
      rows.add([
        '${i + 1}',
        names[i],
        for (final v in _varieties)
          for (final k in _factoryKeys) matrix[names[i]]![v]?[k] ?? '0',
      ]);
    }
    while (rows.length < 3) {
      rows.add(['${rows.length + 1}', '', for (int i = 0; i < 12; i++) '']);
    }
    return rows;
  }

  /// Column-wise SUM of the factory rows (12 values).
  List<String> _factoryTotals(List<List<String>> rows) {
    return [
      for (int c = 0; c < 12; c++)
        _fq(rows.fold<double>(
            0, (sum, r) => sum + (double.tryParse(r[2 + c]) ?? 0))),
    ];
  }

  Widget _buildPurchasePreview(Map<String, dynamic>? data) {
    final dateStr = _formatDate(data?['date']);
    final centre =
    (data?['centre'] ?? 'DEVADURGA').toString().toUpperCase();
    final cropSeason = (data?['cropSeason'] ?? '2025-26').toString();
    final branchOffice =
    (data?['branchOffice'] ?? 'MAHABUBNAGAR').toString().toUpperCase();

    final rows = _purchaseRows(data);
    final factoryRows = _factoryTableRows(data);
    final totals = _factoryTotals(factoryRows);

    final table = Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF94A3B8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _plainRow('THE COTTON CORPORATION OF INDIA LTD', bold: true),
          _plainRow('BRANCH OFFICE :: $branchOffice.', bold: true),
          _plainRow('DAILY PURCHASE REPORT', bold: true),
          _plainRow('CROP SEASON $cropSeason', bold: true, trailing: 'MSP'),
          const Divider(height: 1, thickness: 1, color: Color(0xFF94A3B8)),
          _numRow('1', 'Purchase Date', dateStr, dateStr, dateStr),
          _numRow('2', 'Centre', centre, centre, centre),
          _numRow('3', 'Variety', 'BB MOD', 'BB SPL MOD', 'MECH', bold: true),
          ...rows.map((r) => _numRow(r[0], r[1], r[2], r[3], r[4])),
          _numRow('$_factoryRowNo', 'Factory wise day purchase details',
              'BB MOD', 'BB SPL MOD', 'MECH',
              bold: true),
          _factorySubHeader(),
          ...factoryRows.map(_factoryRowWidget),
          _totalRow(totals),
        ],
      ),
    );

    // 12 value columns need room: scroll sideways on narrow screens.
    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 900.0;
        if (constraints.maxWidth >= minWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: minWidth, child: table),
        );
      },
    );
  }

  List<Map<String, dynamic>> _factoriesForVariety(
      Map<String, dynamic>? data, String variety) {
    if (data == null) return [];

    List<dynamic>? src;
    final ownVariety = (data['variety'] ?? '').toString();

    if (ownVariety == variety) {
      src = data['factories'] as List?;
    } else {
      final others = data['otherVarietiesProgressive'];
      if (others is Map) {
        final bucket = others[variety];
        if (bucket is Map) {
          src = bucket['factories'] as List?;
        }
      }
    }

    if (src == null) return [];
    return src
        .whereType<Map>()
        .map((f) => Map<String, dynamic>.from(f))
        .toList();
  }

  /// ⭐ FIXED: Don't overwrite same factory+variety; sum them instead.
  /// This fixes the mismatch where two factories for BB MOD were showing
  /// only one, or wrong values, because the matrix overwrote entries.
  Map<String, Map<String, Map<String, String>>> _buildFactoryMatrix(
      Map<String, dynamic>? data) {
    final matrix = <String, Map<String, Map<String, String>>>{};

    for (final v in _varieties) {
      final list = _factoriesForVariety(data, v);
      for (final f in list) {
        final name = (f['factoryName'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        matrix.putIfAbsent(name, () => <String, Map<String, String>>{});

        final newQtls = _fq(f['progPurchaseQtls']);
        final newBales = _fq(f['progPurchaseBales']);
        final newTodayQtls = _fq(f['purchaseQtls']);
        final newTodayBales = _fq(f['purchaseBales']);

        final existing = matrix[name]![v];
        if (existing == null) {
          matrix[name]![v] = {
            'todayQtls': newTodayQtls,
            'todayBales': newTodayBales,
            'qtls': newQtls,
            'bales': newBales,
          };
        } else {
          // Sum duplicates rather than overwrite
          double n(String? x) => double.tryParse(x ?? '0') ?? 0;
          matrix[name]![v] = {
            'todayQtls':
            _fq(n(existing['todayQtls']) + n(newTodayQtls)),
            'todayBales':
            _fq(n(existing['todayBales']) + n(newTodayBales)),
            'qtls': _fq(n(existing['qtls']) + n(newQtls)),
            'bales': _fq(n(existing['bales']) + n(newBales)),
          };
        }
      }
    }
    return matrix;
  }

  Widget _factorySubHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(width: _snoW),
            const Expanded(
              flex: 4,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Text('Factory Name',
                    style:
                    TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: _colonW),
            for (int i = 0; i < _varieties.length * 4; i++)
              _gridCell(_factorySubHeaders[i % 4],
                  bold: true, small: true, darkLeft: i % 4 == 0),
          ],
        ),
      ),
    );
  }

  Widget _factoryRowWidget(List<String> r) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _snoW,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Text(r[0],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Text(r[1], style: const TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(
              width: _colonW,
              child: Center(child: Text(':', style: TextStyle(fontSize: 11))),
            ),
            for (int i = 0; i < 12; i++)
              _gridCell(r[2 + i], darkLeft: i % 4 == 0),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PDF EXPORT  ⭐ NEW
  // ============================================================

  Future<void> _exportPdf(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final doc = pw.Document();

      if (_isGroupedWeightList) {
        final list = groupData ?? const <Map<String, dynamic>>[];
        for (int i = 0; i < list.length; i++) {
          doc.addPage(_buildWeightListPdfPage(
            list[i],
            reportIndex: i + 1,
            reportTotal: list.length,
          ));
        }
      } else if (type == ReportType.dailyPurchase) {
        doc.addPage(_buildPurchasePdfPage(data));
      } else if (type == ReportType.dailySeed) {
        doc.addPage(_buildSeedPdfPage(data));
      } else if (type == ReportType.weightList) {
        doc.addPage(_buildWeightListPdfPage(data ?? {}));
      }

      final bytes = await doc.save();

      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: _pdfFileName(),
      );

      if (!context.mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('✅ PDF ready'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('❌ Error generating PDF: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  String _pdfFileName() {
    switch (type) {
      case ReportType.dailyPurchase:
        final centre =
        (data?['centre'] ?? '').toString().toUpperCase();
        return 'PurchaseReport_${centre.isEmpty ? '' : '${centre}_'}${ExportHelper.today()}.pdf';
      case ReportType.dailySeed:
        final centre =
        (data?['centre'] ?? '').toString().toUpperCase();
        return 'SeedReport_${centre.isEmpty ? '' : '${centre}_'}${ExportHelper.today()}.pdf';
      case ReportType.weightList:
        if (_isGroupedWeightList && groupData!.isNotEmpty) {
          final f = groupData!.first;
          final centre = (f['centre'] ?? '').toString().toUpperCase();
          final lot = (f['lotNo'] ?? '').toString();
          return 'WeightList_${centre.isEmpty ? '' : '${centre}_'}${lot.isEmpty ? '' : 'Lot${lot}_'}${ExportHelper.today()}.pdf';
        }
        final centre = (data?['centre'] ?? '').toString().toUpperCase();
        final lot = (data?['lotNo'] ?? '').toString();
        return 'WeightList_${centre.isEmpty ? '' : '${centre}_'}${lot.isEmpty ? '' : 'Lot${lot}_'}${ExportHelper.today()}.pdf';
    }
  }

  // ---------- PURCHASE PDF ----------

// ---------- PURCHASE PDF ----------

  pw.Widget _pdfCell(String text,
      {bool bold = false, bool left = false, double size = 8}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      alignment: left ? pw.Alignment.centerLeft : pw.Alignment.center,
      child: pw.Text(
        text,
        textAlign: left ? pw.TextAlign.left : pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Page _buildPurchasePdfPage(Map<String, dynamic>? data) {
    final dateStr = _formatDate(data?['date']);
    final centre =
    (data?['centre'] ?? 'DEVADURGA').toString().toUpperCase();
    final cropSeason = (data?['cropSeason'] ?? '2025-26').toString();
    final branchOffice =
    (data?['branchOffice'] ?? 'MAHABUBNAGAR').toString().toUpperCase();

    final rows = _purchaseRows(data);
    final factoryRows = _factoryTableRows(data);
    final totals = _factoryTotals(factoryRows);

    // Both tables share the same fixed widths so the variety blocks line up.
    const snoW = 28.0, nameW = 190.0, colonW = 10.0, cellW = 47.0;
    final mainWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(snoW),
      1: const pw.FixedColumnWidth(nameW),
      2: const pw.FixedColumnWidth(colonW),
      3: const pw.FixedColumnWidth(cellW * 4),
      4: const pw.FixedColumnWidth(cellW * 4),
      5: const pw.FixedColumnWidth(cellW * 4),
    };
    final factoryWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(snoW),
      1: const pw.FixedColumnWidth(nameW),
      2: const pw.FixedColumnWidth(colonW),
      for (int i = 0; i < 12; i++) 3 + i: const pw.FixedColumnWidth(cellW),
    };

    pw.TableRow mainRow(String n, String label, String v1, String v2, String v3,
        {bool bold = false}) {
      return pw.TableRow(children: [
        _pdfCell(n, bold: bold),
        _pdfCell(label, bold: bold, left: true),
        _pdfCell(':'),
        _pdfCell(v1, bold: bold),
        _pdfCell(v2, bold: bold),
        _pdfCell(v3, bold: bold),
      ]);
    }

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => [
        pw.Center(
          child: pw.Text('THE COTTON CORPORATION OF INDIA LTD',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Center(
          child: pw.Text('BRANCH OFFICE :: $branchOffice.',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Center(
          child: pw.Text('DAILY PURCHASE REPORT',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Center(
          child: pw.Text('CROP SEASON $cropSeason    MSP',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 8),

        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: mainWidths,
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            mainRow('1', 'Purchase Date', dateStr, dateStr, dateStr),
            mainRow('2', 'Centre', centre, centre, centre),
            mainRow('3', 'Variety', 'BB MOD', 'BB SPL MOD', 'MECH',
                bold: true),
            ...rows.map((r) => mainRow(r[0], r[1], r[2], r[3], r[4])),
            mainRow('$_factoryRowNo', 'Factory wise day purchase details',
                'BB MOD', 'BB SPL MOD', 'MECH',
                bold: true),
          ],
        ),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: factoryWidths,
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _pdfCell(''),
                _pdfCell('Factory Name', bold: true, left: true),
                _pdfCell(''),
                for (int i = 0; i < 12; i++)
                  _pdfCell(_factorySubHeaders[i % 4], bold: true, size: 6.5),
              ],
            ),
            ...factoryRows.map((r) => pw.TableRow(children: [
              _pdfCell(r[0]),
              _pdfCell(r[1], left: true),
              _pdfCell(':'),
              for (int i = 0; i < 12; i++) _pdfCell(r[2 + i]),
            ])),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _pdfCell(''),
                _pdfCell('TOTAL', bold: true, left: true),
                _pdfCell(''),
                for (int i = 0; i < 12; i++) _pdfCell(totals[i], bold: true),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ---------- SEED PDF ----------

// ---------- SEED PDF ----------

  pw.Page _buildSeedPdfPage(Map<String, dynamic>? data) {
    final dateStr = _formatDate(data?['date']);
    final centre = (data?['centre'] ?? '').toString();
    final reportNo = (data?['reportNo'] ?? '1').toString();
    final factories = _seedFactoryList(data);

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => [
        pw.Center(
          child: pw.Text('SEED REPORT',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('CENTRE: ${centre.isEmpty ? 'N/A' : centre.toUpperCase()}'),
            pw.Text('DATE: $dateStr'),
            pw.Text('REPORT NO.: $reportNo'),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(width: 0.4),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          headerStyle: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 7),
          headers: [
            'S.No.',
            'Factory',
            'Variety',
            'Realisable',
            'Realised',
            'Sold Qty',
            'Prog. Del.',
            'Kaps1',
            'Ready1',
            'Total1',
            'Kaps2',
            'Ready2',
            'Total2',
            'MR Min',
            'MR Max',
          ],
          data: factories.asMap().entries.map((e) {
            final i = e.key;
            final f = e.value;
            final c = _computeSeedRow(f);
            final variety = (f['variety'] ?? '').toString();
            return [
              '${i + 1}',
              f['factoryName']?.toString() ?? '',
              variety.isEmpty ? '—' : variety,
              c['realisable']!,
              c['realised']!,
              c['soldQty']!,
              c['progDelivery']!,
              c['kaps1']!,
              c['ready1']!,
              c['total1']!,
              c['kaps2']!,
              c['ready2']!,
              c['total2']!,
              c['marketRateMin']!,
              c['marketRateMax']!,
            ];
          }).toList(),
        ),
      ],
    );
  }

  // ---------- WEIGHT LIST PDF ----------

  pw.Page _buildWeightListPdfPage(
      Map<String, dynamic> d, {
        int? reportIndex,
        int? reportTotal,
      }) {
    String f(String k) => (d[k] ?? '').toString();
    final centre = f('centre').toUpperCase();
    final bales = _weightBales(d);

    // One table per block of 50 bales (10 rows x 5 column pairs), each with
    // its own S.L.NO / KGS header and a TOTAL row, as in the Excel format.
    final blockTables = <pw.Widget>[];
    if (bales.isNotEmpty) {
      final blockCount = (bales.length / 50).ceil();
      for (int b = 0; b < blockCount; b++) {
        final start = b * 50;
        final remaining = bales.length - start;
        final count = remaining > 50 ? 50 : remaining;
        final rows = (count / 5).ceil();

        final tableRows = <pw.TableRow>[
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              for (int c = 0; c < 5; c++) ...[
                _pdfCell('S.L.NO', bold: true),
                _pdfCell('KGS', bold: true),
              ],
            ],
          ),
        ];

        for (int rr = 0; rr < rows; rr++) {
          final cells = <pw.Widget>[];
          for (int c = 0; c < 5; c++) {
            final i = rr + (c * rows);
            if (i < count) {
              final e = bales[start + i];
              cells.add(_pdfCell((e['baleNo'] ?? (start + i + 1)).toString(),
                  size: 8));
              cells.add(_pdfCell(_fq(e['weight']), size: 8));
            } else {
              cells.add(_pdfCell(''));
              cells.add(_pdfCell(''));
            }
          }
          tableRows.add(pw.TableRow(children: cells));
        }

        // TOTAL of each KGS column for this block
        tableRows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            for (int c = 0; c < 5; c++) ...[
              _pdfCell(c == 0 ? 'TOTAL ::' : '', bold: true, size: 8),
              _pdfCell(_blockColumnSum(bales, start, count, c),
                  bold: true, size: 8),
            ],
          ],
        ));

        blockTables.add(pw.Table(
          border: pw.TableBorder.all(width: 0.4),
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: tableRows,
        ));
        if (b < blockCount - 1) blockTables.add(pw.SizedBox(height: 10));
      }
    }

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        if (reportIndex != null && reportTotal != null)
          pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey900,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Text(
                'REPORT $reportIndex OF $reportTotal',
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold),
              ),
            ),
          ),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text('THE COTTON CORPORATION OF INDIA LTD.',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Center(
          child: pw.Text('CENTRE ::: $centre',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Center(
          child: pw.Text('F.P.BALES WEIGHT LIST AT THE TIME OF PRESSING',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 8),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('VARIETY: ${f('variety')}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('LOT NO: ${f('lotNo')}', style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('DT.OF PRESSING: ${_pressingDateText(d, bales.length)}',
                style: const pw.TextStyle(fontSize: 9)),
            pw.Text('P.R.NO: ${f('prNo')}', style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('P.M.NO: ${f('pmNo')}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('NO OF BALES: ${f('noOfBales').isEmpty ? bales.length.toString() : f('noOfBales')}',
                style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('CROP YEAR: ${f('cropYear')}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('S.B.NO: ${f('sampleBaleNo')}', style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('UBIN NO: ${f('ubinNo')}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('LOT AVG MOISTURE: ${f('moisture')}',
                style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
        pw.Text('NAME OF THE GODOWN: ${f('godown')}',
            style: const pw.TextStyle(fontSize: 9)),
        pw.Text('FACTORY NAME ::: ${f('pressingFactory')}',
            style: const pw.TextStyle(fontSize: 9)),

        pw.SizedBox(height: 8),

        ...blockTables,

        pw.SizedBox(height: 10),

        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('TOTAL GROSS WT :: ${_num(d['totalGrossWeight'])}',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('TOTAL TARE WT :: ${_num(d['tareWeight'])}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Text('TOTAL NET WT :: ${_num(d['totalNettWeight'])}',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),

        pw.SizedBox(height: 24),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('For The Cotton Corporation of India Ltd.',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 32),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Factory Owner / Rep', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Centre Incharge',
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // EXCEL EXPORT (unchanged)
  // ============================================================

  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();

    try {
      final excel = excel_lib.Excel.createExcel();
      String fileName;
      switch (type) {
        case ReportType.dailyPurchase:
          fileName = _fillPurchaseSheet(excel);
          break;
        case ReportType.dailySeed:
          fileName = _fillSeedSheet(excel);
          break;
        case ReportType.weightList:
          fileName = _isGroupedWeightList
              ? _fillWeightListGroupSheet(excel)
              : _fillWeightListSheet(excel);
          break;
      }

      final path = await ExportHelper.saveExcel(excel, fileName);
      messenger.showSnackBar(SnackBar(
        content: Text(path != null
            ? '✅ Exported to: $path'
            : '❌ Could not save the file'),
        backgroundColor: path != null ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('❌ Error exporting report: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  String _fileDate(String dateStr) =>
      dateStr.isEmpty ? ExportHelper.today() : dateStr.replaceAll('.', '');

  String _fillPurchaseSheet(excel_lib.Excel excel) {
    final sheet = ExportHelper.newSheet(excel, 'Purchase Report');
    final dateStr = _formatDate(data?['date']);
    final centre = (data?['centre'] ?? 'DEVADURGA').toString().toUpperCase();
    final cropSeason = (data?['cropSeason'] ?? '2025-26').toString();
    final branchOffice =
    (data?['branchOffice'] ?? 'MAHABUBNAGAR').toString().toUpperCase();

    // Columns: 0 S.No | 1 label | 2 ':' | 3..14 values (3 varieties x 4)
    const lastCol = 14;

    void merge(int row, int c1, int c2) {
      sheet.merge(
        excel_lib.CellIndex.indexByColumnRow(columnIndex: c1, rowIndex: row),
        excel_lib.CellIndex.indexByColumnRow(columnIndex: c2, rowIndex: row),
      );
    }

    int add(List<dynamic> cells) {
      sheet.appendRow(cells);
      return sheet.maxRows - 1;
    }

    void title(String text, {String trailing = ''}) {
      final r = add([
        text,
        for (int i = 1; i < lastCol; i++) '',
        trailing,
      ]);
      merge(r, 0, trailing.isEmpty ? lastCol : lastCol - 1);
    }

    // Main row: each variety value spans 4 columns (D:G, H:K, L:O)
    void spanRow(String n, String label, String v1, String v2, String v3) {
      final r = add([
        n, label, ':',
        v1, '', '', '',
        v2, '', '', '',
        v3, '', '', '',
      ]);
      merge(r, 3, 6);
      merge(r, 7, 10);
      merge(r, 11, 14);
    }

    title('THE COTTON CORPORATION OF INDIA LTD');
    title('BRANCH OFFICE :: $branchOffice.');
    title('DAILY PURCHASE REPORT');
    title('CROP SEASON $cropSeason', trailing: 'MSP');

    spanRow('1', 'Purchase Date', dateStr, dateStr, dateStr);
    spanRow('2', 'Centre', centre, centre, centre);
    spanRow('3', 'Variety', 'BB MOD', 'BB SPL MOD', 'MECH');
    for (final r in _purchaseRows(data)) {
      spanRow(r[0], r[1], r[2], r[3], r[4]);
    }
    spanRow('$_factoryRowNo', 'Factory wise day purchase details',
        'BB MOD', 'BB SPL MOD', 'MECH');

    add([
      '',
      'Factory Name',
      '',
      for (int i = 0; i < 12; i++)
        _factorySubHeaders[i % 4].replaceAll('\n', ' '),
    ]);

    final factoryRows = _factoryTableRows(data);
    for (final r in factoryRows) {
      add([r[0], r[1], ':', ...r.sublist(2)]);
    }
    add(['', 'TOTAL', '', ..._factoryTotals(factoryRows)]);

    sheet.setColWidth(0, 6);
    sheet.setColWidth(1, 48);
    sheet.setColWidth(2, 3);
    for (int c = 3; c <= lastCol; c++) {
      sheet.setColWidth(c, 14);
    }

    return 'PurchaseReport_${ExportHelper.safe(centre)}_${_fileDate(dateStr)}.xlsx';
  }

  String _fillSeedSheet(excel_lib.Excel excel) {
    final sheet = ExportHelper.newSheet(excel, 'Seed Report');
    final dateStr = _formatDate(data?['date']);
    final centre = (data?['centre'] ?? '').toString();
    final reportNo = (data?['reportNo'] ?? '1').toString();
    final factories = _seedFactoryList(data);

    sheet.appendRow(['SEED REPORT']);
    sheet.appendRow([
      'CENTRE: ${centre.isEmpty ? 'N/A' : centre.toUpperCase()}',
      'DATE: $dateStr',
      'REPORT NO.: $reportNo',
    ]);
    sheet.appendRow([]);

    sheet.appendRow([
      '',
      '',
      '',
      'PROG. QTY.',
      '',
      '',
      '',
      'UNSOLD',
      '',
      '',
      'SOLD BUT NOT LIFTED',
      '',
      '',
      'MARKET RATE',
      '',
    ]);
    sheet.appendRow([
      'S.No.',
      'Factory Name',
      'Variety',
      'Realisable',
      'Realised',
      'Sold Qty',
      'Prog. Delivery',
      'Kaps',
      'Ready',
      'Total',
      'Kaps',
      'Ready',
      'Total',
      'Market Min',
      'Market Max',
    ]);

    for (int i = 0; i < factories.length; i++) {
      final f = factories[i];
      final c = _computeSeedRow(f);
      final variety = (f['variety'] ?? '').toString();
      sheet.appendRow([
        '${i + 1}',
        f['factoryName']?.toString() ?? '',
        variety.isEmpty ? '—' : variety,
        c['realisable']!,
        c['realised']!,
        c['soldQty']!,
        c['progDelivery']!,
        c['kaps1']!,
        c['ready1']!,
        c['total1']!,
        c['kaps2']!,
        c['ready2']!,
        c['total2']!,
        c['marketRateMin']!,
        c['marketRateMax']!,
      ]);
    }

    return 'SeedReport_${ExportHelper.safe(centre)}_${_fileDate(dateStr)}.xlsx';
  }

  String _fillWeightListSheet(excel_lib.Excel excel) {
    final sheet = ExportHelper.newSheet(excel, 'Weight List');
    final d = data ?? <String, dynamic>{};
    _writeWeightListBlockToSheet(sheet, d, startRow: 0);

    String f(String k) => (d[k] ?? '').toString();
    final centre = f('centre').toUpperCase();
    final dateStr = _formatDate(d['date']);
    final lot = f('lotNo');
    return 'WeightList_${ExportHelper.safe(centre)}_${lot.isEmpty ? '' : 'Lot${ExportHelper.safe(lot)}_'}${_fileDate(dateStr)}.xlsx';
  }

  String _fillWeightListGroupSheet(excel_lib.Excel excel) {
    final sheet = ExportHelper.newSheet(excel, 'Weight List');
    final list = groupData ?? const <Map<String, dynamic>>[];
    int row = 0;
    for (int i = 0; i < list.length; i++) {
      row = _writeWeightListBlockToSheet(sheet, list[i], startRow: row);
      row += 2;
    }

    String fileName = 'WeightList_Group_${ExportHelper.today()}.xlsx';
    if (list.isNotEmpty) {
      final f = list.first;
      final centre = (f['centre'] ?? '').toString().toUpperCase();
      final lot = (f['lotNo'] ?? '').toString();
      fileName =
      'WeightList_${ExportHelper.safe(centre)}_${lot.isEmpty ? '' : 'Lot${ExportHelper.safe(lot)}_'}${ExportHelper.today()}.xlsx';
    }
    return fileName;
  }

  int _writeWeightListBlockToSheet(
      excel_lib.Sheet sheet,
      Map<String, dynamic> d, {
        required int startRow,
      }) {
    String f(String k) => (d[k] ?? '').toString();
    final centre = f('centre').toUpperCase();
    final bales = _weightBales(d);

    int r(int offset) => startRow + offset;

    _sheetAppendMerged(sheet, r(0), ['THE COTTON CORPORATION OF INDIA LTD.']);
    _sheetAppendMerged(sheet, r(1), ['CENTRE ::: $centre']);
    _sheetAppendMerged(
        sheet, r(2), ['F.P.BALES WEIGHT LIST AT THE TIME OF PRESSING']);
    sheet.appendRow([]);

    _sheetAppendDetailRow(
      sheet,
      r(4),
      l1: 'VARIETY',
      v1: f('variety'),
      l2: 'LOT NO:',
      v2: f('lotNo'),
    );
    _sheetAppendDetailRow(
      sheet,
      r(5),
      l1: 'DT.OF PRESSING',
      v1: _pressingDateText(d, bales.length),
      l2: 'P.R.NO:',
      v2: f('prNo'),
    );
    _sheetAppendDetailRow(
      sheet,
      r(6),
      l1: 'P.M.NO',
      v1: f('pmNo'),
      l2: 'NO OF BALES :',
      v2: f('noOfBales').isEmpty ? bales.length.toString() : f('noOfBales'),
    );
    _sheetAppendDetailRow(
      sheet,
      r(7),
      l1: 'CROP YEAR',
      v1: f('cropYear'),
      l2: 'S.B.NO :',
      v2: f('sampleBaleNo'),
    );
    _sheetAppendDetailRow(
      sheet,
      r(8),
      l1: 'UBIN NO',
      v1: f('ubinNo'),
      l2: 'LOT AVG MOISTURE',
      v2: f('moisture'),
    );
    sheet.appendRow(['NAME OF THE GODOWN: ${f('godown')}']);
    sheet.appendRow([]);
    sheet.appendRow(['FACTORY NAME :::', f('pressingFactory')]);

    int row = r(12);
    final blockCount = bales.isEmpty ? 1 : (bales.length / 50).ceil();
    for (int b = 0; b < blockCount; b++) {
      final start = b * 50;
      final remaining = bales.length - start;
      final count = remaining > 50 ? 50 : (remaining < 0 ? 0 : remaining);
      final rows = (count / 5).ceil();

      sheet.appendRow([
        for (int c = 0; c < 5; c++) ...['S.L.NO', 'KGS']
      ]);
      row++;

      for (int rr = 0; rr < rows; rr++) {
        final cells = <dynamic>[];
        for (int c = 0; c < 5; c++) {
          final i = rr + (c * rows);
          if (i < count) {
            final e = bales[start + i];
            cells
              ..add(e['baleNo'] ?? (start + i + 1))
              ..add(_num(e['weight']));
          } else {
            cells..add('')..add('');
          }
        }
        sheet.appendRow(cells);
        row++;
      }

      final totals = <dynamic>[];
      for (int c = 0; c < 5; c++) {
        totals
          ..add(c == 0 ? 'TOTAL ::' : '')
          ..add(_blockColumnSum(bales, start, count, c));
      }
      sheet.appendRow(totals);
      row++;

      if (b < blockCount - 1) {
        sheet.appendRow([]);
        row++;
      }
    }

    sheet.appendRow([]);
    row++;
    sheet.appendRow(['', '', '', '', '', 'TOTAL GROSS WT ::', _num(d['totalGrossWeight'])]);
    row++;
    sheet.appendRow(['', '', '', '', '', 'TOTAL TARE WT    ::', _num(d['tareWeight'])]);
    row++;
    sheet.appendRow(['', '', '', '', '', 'TOTAL NET WT     ::', _num(d['totalNettWeight'])]);
    row++;

    sheet.appendRow([]);
    row++;
    sheet.appendRow(['', '', '', '', '', 'For The Cotton Corporation of India Ltd.']);
    row++;
    sheet.appendRow([]);
    row++;
    sheet.appendRow(['Factory Owner / Rep', '', '', '', '', 'Centre Incharge']);
    row++;

    return row;
  }

  void _sheetAppendMerged(excel_lib.Sheet sheet, int row, List<dynamic> cells) {
    sheet.appendRow(cells);
  }

  void _sheetAppendDetailRow(
      excel_lib.Sheet sheet,
      int row, {
        required String l1,
        required String v1,
        required String l2,
        required String v2,
      }) {
    sheet.appendRow([l1, v1, '', '', '', l2, v2]);
  }

  List<Map<String, dynamic>> _weightBales(Map<String, dynamic> d) {
    final bales = <Map<String, dynamic>>[];
    final raw = d['baleEntries'];
    if (raw is List) {
      for (final b in raw) {
        if (b is Map) bales.add(Map<String, dynamic>.from(b));
      }
    }
    return bales;
  }

  num _num(dynamic v) {
    if (v == null) return 0;
    final d = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    return d == d.roundToDouble()
        ? d.toInt()
        : double.parse(d.toStringAsFixed(2));
  }

  String _pressingDateText(Map<String, dynamic> d, int baleCount) {
    final typed = (d['pressingDate'] ?? '').toString().trim();
    if (typed.isNotEmpty) return typed;

    final n = (d['noOfBales'] ?? baleCount).toString();
    DateTime? dt;
    final v = d['date'];
    if (v is DateTime) dt = v;
    if (v is String) dt = DateTime.tryParse(v);
    if (dt == null) return '$n BALES:';
    return '$n BALES: ${dt.day}-${dt.month}-${dt.year}';
  }

  String _blockColumnSum(
      List<Map<String, dynamic>> bales, int start, int count, int c) {
    final rows = (count / 5).ceil();
    double sum = 0;
    for (int r = 0; r < rows; r++) {
      final i = r + (c * rows);
      if (i >= count) break;
      final w = bales[start + i]['weight'];
      sum += w is num ? w.toDouble() : double.tryParse(w.toString()) ?? 0;
    }
    return _fq(sum);
  }

  // ============================================================
  // SHARED ROW / CELL HELPERS
  // ============================================================

  Widget _plainRow(String text, {bool bold = false, String? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          const SizedBox(width: 32),
          Expanded(
            child: Text(text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  color: const Color(0xFF0F172A),
                )),
          ),
          if (trailing != null)
            Text(trailing,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                )),
        ],
      ),
    );
  }

  static const double _snoW = 32;
  static const double _colonW = 12;

  /// One cell of the 12-column value grid. flex 2 = one column,
  /// flex 8 = one variety block spanning four columns.
  Widget _gridCell(String value,
      {bool bold = false,
        bool small = false,
        int flex = 2,
        bool darkLeft = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: small ? 2 : 6),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: darkLeft
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFFE2E8F0),
              width: darkLeft ? 1 : 0.5,
            ),
          ),
        ),
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: small ? 9 : 11,
            fontWeight: (bold || small) ? FontWeight.w700 : FontWeight.w500,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  Widget _numRow(String n, String label, String v1, String v2, String v3,
      {bool bold = false}) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _snoW,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Text(n,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    )),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Text(label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                      color: const Color(0xFF334155),
                    )),
              ),
            ),
            const SizedBox(
              width: _colonW,
              child: Center(child: Text(':', style: TextStyle(fontSize: 11))),
            ),
            _gridCell(v1, bold: bold, flex: 8, darkLeft: true),
            _gridCell(v2, bold: bold, flex: 8, darkLeft: true),
            _gridCell(v3, bold: bold, flex: 8, darkLeft: true),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(List<String> totals) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(top: BorderSide(color: Color(0xFF94A3B8), width: 1)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(width: _snoW),
            const Expanded(
              flex: 4,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Text('TOTAL',
                    style:
                    TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: _colonW),
            for (int i = 0; i < 12; i++)
              _gridCell(totals[i], bold: true, darkLeft: i % 4 == 0),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEED HELPERS
  // ============================================================

  String _fmtNum(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  List<Map<String, dynamic>> _seedFactoryList(Map<String, dynamic>? data) {
    final src = data?['seedFactories'] ?? data?['factories'];
    if (src is! List) return [];
    return src
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  Map<String, String> _computeSeedRow(Map<String, dynamic> f) {
    final realisable = _num(f['realisable']).toDouble();
    final realised = _num(f['realised']).toDouble();
    final soldQty = _num(f['soldQty']).toDouble();
    final progDelivery = _num(f['progDelivery']).toDouble();

    final ready1 = realised < soldQty ? 0.0 : realised - soldQty;
    final kaps1 = realisable - soldQty - ready1;
    final total1 = kaps1 + ready1;

    final kaps2 = realised > soldQty ? 0.0 : soldQty - realised;
    final ready2 = soldQty - progDelivery - kaps2;
    final total2 = kaps2 + ready2;

    return {
      'realisable': _fmtNum(realisable),
      'realised': _fmtNum(realised),
      'soldQty': _fmtNum(soldQty),
      'progDelivery': _fmtNum(progDelivery),
      'kaps1': _fmtNum(kaps1),
      'ready1': _fmtNum(ready1),
      'total1': _fmtNum(total1),
      'kaps2': _fmtNum(kaps2),
      'ready2': _fmtNum(ready2),
      'total2': _fmtNum(total2),
      'marketRateMin': _fmtNum(_num(f['marketRateMin'])),
      'marketRateMax': _fmtNum(_num(f['marketRateMax'])),
    };
  }

  Widget _buildSeedPreview(Map<String, dynamic>? data) {
    final dateStr = _formatDate(data?['date']);
    final centre = (data?['centre'] ?? '').toString();
    final reportNo = (data?['reportNo'] ?? '1').toString();

    final factories = _seedFactoryList(data);

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
              child: Text(
                centre.isEmpty ? 'N/A' : centre.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
              ),
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
              child: Text(
                'No factory data available',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
              WidgetStateProperty.all(const Color(0xFFE2E8F0)),
              columnSpacing: 18,
              columns: const [
                DataColumn(label: Text('S.No.')),
                DataColumn(label: Text('Factory Name')),
                DataColumn(label: Text('Variety')),
                DataColumn(label: Text('Realisable')),
                DataColumn(label: Text('Realised')),
                DataColumn(label: Text('Sold Qty')),
                DataColumn(label: Text('Prog. Delivery')),
                DataColumn(label: Text('Kaps')),
                DataColumn(label: Text('Ready')),
                DataColumn(label: Text('Total')),
                DataColumn(label: Text('Kaps')),
                DataColumn(label: Text('Ready')),
                DataColumn(label: Text('Total')),
                DataColumn(label: Text('Market Min')),
                DataColumn(label: Text('Market Max')),
              ],
              rows: factories.asMap().entries.map((e) {
                final i = e.key;
                final f = e.value;
                final c = _computeSeedRow(f);
                final variety = (f['variety'] ?? '').toString().isEmpty
                    ? '—'
                    : f['variety'].toString();

                return DataRow(cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(Text(f['factoryName']?.toString() ?? '')),
                  DataCell(Text(variety)),
                  DataCell(Text(c['realisable']!)),
                  DataCell(Text(c['realised']!)),
                  DataCell(Text(c['soldQty']!)),
                  DataCell(Text(c['progDelivery']!)),
                  DataCell(Text(c['kaps1']!)),
                  DataCell(Text(c['ready1']!)),
                  DataCell(Text(c['total1']!)),
                  DataCell(Text(c['kaps2']!)),
                  DataCell(Text(c['ready2']!)),
                  DataCell(Text(c['total2']!)),
                  DataCell(Text(c['marketRateMin']!)),
                  DataCell(Text(c['marketRateMax']!)),
                ]);
              }).toList(),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // WEIGHT LIST PREVIEW — SINGLE
  // ============================================================

  Widget _buildWeightListPreview(Map<String, dynamic>? data) {
    if (data == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No data available',
              style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }
    return _buildSingleWeightListBlock(data);
  }

  Widget _buildGroupedWeightListPreview() {
    final list = groupData ?? const <Map<String, dynamic>>[];
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No data available',
              style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < list.length; i++) ...[
          _reportPill(i + 1, list.length),
          const SizedBox(height: 8),
          _buildSingleWeightListBlock(list[i]),
          if (i < list.length - 1) const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _reportPill(int index, int total) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'REPORT $index OF $total',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSingleWeightListBlock(Map<String, dynamic> data) {
    String s(String k) => (data[k] ?? '').toString();
    final centre = s('centre').toUpperCase();
    final bales = _weightBales(data);
    final blockCount = bales.isEmpty ? 0 : (bales.length / 50).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF94A3B8)),
            color: const Color(0xFFF8FAFC),
          ),
          child: Column(
            children: [
              const Text('THE COTTON CORPORATION OF INDIA LTD.',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text('CENTRE ::: $centre',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              const Text('F.P.BALES WEIGHT LIST AT THE TIME OF PRESSING',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155))),
              const SizedBox(height: 8),
              _wMetaRow('VARIETY', s('variety'), 'LOT NO:', s('lotNo')),
              _wMetaRow(
                  'DT.OF PRESSING',
                  _pressingDateText(data, bales.length),
                  'P.R.NO:',
                  s('prNo')),
              _wMetaRow('P.M.NO', s('pmNo'), 'NO OF BALES :',
                  s('noOfBales')),
              _wMetaRow('CROP YEAR', s('cropYear'), 'S.B.NO :',
                  s('sampleBaleNo')),
              _wMetaRow('UBIN NO', s('ubinNo'), 'LOT AVG MOISTURE',
                  s('moisture')),
              _wMetaRow('NAME OF THE GODOWN:', s('godown'), '', ''),
              _wMetaRow('FACTORY NAME :::', s('pressingFactory'), '', ''),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (bales.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No bale weights entered yet',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          )
        else
          for (int b = 0; b < blockCount; b++) _buildWeightBlock(bales, b),

        const SizedBox(height: 4),

        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _summaryRow('TOTAL GROSS WT ::', s('totalGrossWeight'), false),
              const SizedBox(height: 4),
              _summaryRow('TOTAL TARE WT ::', s('tareWeight'), false),
              const SizedBox(height: 4),
              _summaryRow('TOTAL NET WT ::', s('totalNettWeight'), true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Align(
          alignment: Alignment.centerRight,
          child: Text('For The Cotton Corporation of India Ltd.',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A))),
        ),
        const SizedBox(height: 28),
        const Row(
          children: [
            Expanded(
              child: Text('Factory Owner / Rep',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFF0F172A))),
            ),
            Expanded(
              child: Text('Centre Incharge',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeightBlock(List<Map<String, dynamic>> bales, int block) {
    final start = block * 50;
    final remaining = bales.length - start;
    final count = remaining > 50 ? 50 : remaining;
    final rows = (count / 5).ceil();

    final rowWidgets = <Widget>[];
    for (int r = 0; r < rows; r++) {
      final cells = <Widget>[];
      for (int c = 0; c < 5; c++) {
        final i = r + (c * rows);
        if (i >= count) {
          cells.add(const Expanded(child: _PreviewDataCell('')));
          cells.add(const Expanded(child: _PreviewDataCell('')));
        } else {
          final e = bales[start + i];
          cells.add(Expanded(
              child: _PreviewDataCell(
                  (e['baleNo'] ?? (start + i + 1)).toString())));
          cells.add(Expanded(child: _PreviewDataCell(_fq(e['weight']))));
        }
      }
      rowWidgets.add(Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(children: cells),
      ));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF94A3B8)),
      ),
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: const Row(
              children: [
                Expanded(child: _PreviewHeaderCell('S.L.NO')),
                Expanded(child: _PreviewHeaderCell('KGS')),
                Expanded(child: _PreviewHeaderCell('S.L.NO')),
                Expanded(child: _PreviewHeaderCell('KGS')),
                Expanded(child: _PreviewHeaderCell('S.L.NO')),
                Expanded(child: _PreviewHeaderCell('KGS')),
                Expanded(child: _PreviewHeaderCell('S.L.NO')),
                Expanded(child: _PreviewHeaderCell('KGS')),
                Expanded(child: _PreviewHeaderCell('S.L.NO')),
                Expanded(child: _PreviewHeaderCell('KGS')),
              ],
            ),
          ),
          ...rowWidgets,
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(
                top: BorderSide(color: Color(0xFF94A3B8), width: 1.2),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                for (int c = 0; c < 5; c++) ...[
                  Expanded(
                    child: _PreviewDataCell(c == 0 ? 'TOTAL ::' : '',
                        bold: true),
                  ),
                  Expanded(
                    child: _PreviewDataCell(
                      _blockColumnSum(bales, start, count, c),
                      bold: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wMetaRow(String l1, String v1, String l2, String v2) {
    Widget half(String l, String v) => Expanded(
      child: Row(
        children: [
          Text('$l ',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B))),
          Expanded(
            child: Text(v,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          half(l1, v1),
          if (l2.isNotEmpty) half(l2, v2) else const Spacer(),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, bool highlight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155))),
        const SizedBox(width: 16),
        Container(
          constraints: const BoxConstraints(minWidth: 100),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value.isEmpty ? '—' : value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlight
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewHeaderCell extends StatelessWidget {
  final String text;
  const _PreviewHeaderCell(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A)));
  }
}

class _PreviewDataCell extends StatelessWidget {
  final String text;
  final bool bold;
  const _PreviewDataCell(this.text, {this.bold = false});
  @override
  Widget build(BuildContext context) {
    return Text(text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: const Color(0xFF0F172A),
        ));
  }
}