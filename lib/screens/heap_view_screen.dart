import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as excel_lib;
import '../services/ExportHelper.java';
import '../services/apiservice.dart';

// Legal paper — 8.5" × 14" = 612 × 1008 pt
// (PdfPageFormat has no const constructor, so these must be top-level final.)
final PdfPageFormat kLegalPortrait = PdfPageFormat(612, 1008);
final PdfPageFormat kLegalLandscape = PdfPageFormat(1008, 612);

class HeapViewScreen extends StatefulWidget {
  final Map<String, dynamic> heapData;

  const HeapViewScreen({super.key, required this.heapData});

  @override
  State<HeapViewScreen> createState() => _HeapViewScreenState();
}

class _HeapViewScreenState extends State<HeapViewScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  Map<String, double> _totals = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ============================================================
  // LOAD rows from factory purchase reports
  // ============================================================
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final h = widget.heapData;
    final centre = (h['centre'] ?? '').toString();
    final factory = (h['factoryName'] ?? '').toString();
    final variety = (h['variety'] ?? '').toString();
    final rawFrom = h['fromDate'];
    final rawTo = h['toDate'];

    if (centre.isEmpty || factory.isEmpty || variety.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Heap is missing centre/factory/variety';
      });
      return;
    }

    DateTime fromDate;
    DateTime toDate;
    try {
      fromDate = DateTime.parse(rawFrom.toString());
      toDate = DateTime.parse(rawTo.toString());
    } catch (_) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid date range on heap';
      });
      return;
    }

    final response = await ApiService.getPurchaseEntriesForHeap(
      centre: centre,
      factoryName: factory,
      variety: variety,
      fromDate: fromDate,
      toDate: toDate,
    );

    if (!mounted) return;

    if (!response.success) {
      setState(() {
        _isLoading = false;
        _error = response.message;
      });
      return;
    }

    final list = (response.data?['rows'] as List?) ?? [];
    final rows = list
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();

    setState(() {
      _rows = rows;
      _totals = _computeTotals(rows);
      _isLoading = false;
    });
  }

  // ============================================================
  // Weighted averages per the Excel formulas
  // ============================================================
  Map<String, double> _computeTotals(List<Map<String, dynamic>> rows) {
    double totalQty = 0;
    for (final r in rows) {
      totalQty += (r['quantityQtls'] as num?)?.toDouble() ?? 0;
    }
    double weighted(String field) {
      if (totalQty <= 0) return 0;
      double acc = 0;
      for (final r in rows) {
        final q = (r['quantityQtls'] as num?)?.toDouble() ?? 0;
        final v = (r[field] as num?)?.toDouble() ?? 0;
        acc += q * v;
      }
      return acc / totalQty;
    }

    return {
      'quantityQtls': totalQty,
      'avgRate': weighted('avgRate'),
      'lintPct': weighted('lintPct'),
      'seedPct': weighted('seedPct'),
      'miscPct': 0,
      'shortagePct': weighted('shortagePct'),
      'seedRate': weighted('seedRate'),
      'profExp': weighted('profExp'),
      'padtha': weighted('padtha'),
      'procCycle': 7,
    };
  }

  // ============================================================
  // Build
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heap Report'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: _rows.isEmpty ? null : () => _exportPdf(context),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Excel',
            onPressed: _rows.isEmpty ? null : () => _exportExcel(context),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError(_error!)
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _HeapReportCard(
          heapData: widget.heapData,
          rows: _rows,
          totals: _totals,
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(msg, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  // ============================================================
  // PDF EXPORT
  // ============================================================
  Future<void> _exportPdf(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final doc = pw.Document();
      doc.addPage(_buildPdfPage(widget.heapData, _rows, _totals));
      final bytes = await doc.save();

      final centre =
      (widget.heapData['centre'] ?? '').toString().toUpperCase();
      final heapNo = (widget.heapData['heapNo'] ?? '').toString();

      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Heap_${centre}_Heap${heapNo}_${ExportHelper.today()}.pdf',
      );

      messenger.showSnackBar(const SnackBar(
        content: Text('✅ PDF ready'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('❌ Error: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  pw.Widget _pdfCell(
      String text, {
        bool bold = false,
        bool left = false,
        double size = 7.5,
        double vPad = 2,
      }) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: vPad),
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

  static String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      return DateFormat('dd.MM.yyyy').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return '';
    }
  }

  static String _num(dynamic v, {int decimals = 2}) {
    if (v == null) return '0';
    final d = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toStringAsFixed(decimals);
  }

  pw.Page _buildPdfPage(
      Map<String, dynamic> h,
      List<Map<String, dynamic>> rows,
      Map<String, double> totals,
      ) {
    final mainWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(20),
      1: const pw.FixedColumnWidth(55),
      2: const pw.FixedColumnWidth(40),
      3: const pw.FixedColumnWidth(40),
      4: const pw.FixedColumnWidth(32),
      5: const pw.FixedColumnWidth(32),
      6: const pw.FixedColumnWidth(32),
      7: const pw.FixedColumnWidth(40),
      8: const pw.FixedColumnWidth(38),
      9: const pw.FixedColumnWidth(42),
      10: const pw.FixedColumnWidth(42),
      11: const pw.FixedColumnWidth(32),
      12: const pw.FixedColumnWidth(32),
    };

    final purchaseHeader = [
      'Sl.\nNo.',
      'Date of\nPurchase',
      'Quantity\nQtls.',
      'Avg.\nRate',
      'Lint %',
      'Seed %',
      'Misc %',
      'Shortage %',
      'Seed\nRate',
      'Prof.\nExp.',
      'Padtha',
      'Proc.\nCycle',
      'Ceiling',
    ];

    final calcHeader = [
      'Qty ×\nAvg',
      'Qty ×\nLint%',
      'Qty ×\nSeed%',
      'Qty ×\nMisc%',
      'Qty ×\nShort%',
      'Qty ×\nSeed\nRate',
      'Qty ×\nProf\nExp',
      'Qty ×\nPadtha',
      'Qty ×\nProc\nCycle',
    ];

    final calcWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(20),
      1: const pw.FixedColumnWidth(55),
      for (int i = 0; i < 9; i++) 2 + i: const pw.FixedColumnWidth(42),
    };

    pw.TableRow dataRow(int i, Map<String, dynamic> r) {
      final qty = (r['quantityQtls'] as num?)?.toDouble() ?? 0;
      return pw.TableRow(children: [
        _pdfCell('${i + 1}'),
        _pdfCell(_fmtDate(r['date'])),
        _pdfCell(_num(qty)),
        _pdfCell(_num(r['avgRate'])),
        _pdfCell(_num(r['lintPct'])),
        _pdfCell(_num(r['seedPct'])),
        _pdfCell(_num(r['miscPct'] ?? 0, decimals: 0)),
        _pdfCell(_num(r['shortagePct'])),
        _pdfCell(_num(r['seedRate'])),
        _pdfCell(_num(r['profExp'])),
        _pdfCell(_num(r['padtha'])),
        _pdfCell('${(r['procCycle'] as num?)?.toInt() ?? 7}'),
        _pdfCell((r['ceiling'] ?? 'MSP').toString()),
      ]);
    }

    pw.TableRow calcRow(int i, Map<String, dynamic> r) {
      final q = (r['quantityQtls'] as num?)?.toDouble() ?? 0;
      double v(String k) => (r[k] as num?)?.toDouble() ?? 0;
      final proc = (r['procCycle'] as num?)?.toInt() ?? 7;
      return pw.TableRow(children: [
        _pdfCell('${i + 1}'),
        _pdfCell(_fmtDate(r['date'])),
        _pdfCell(_num(q * v('avgRate'))),
        _pdfCell(_num(q * v('lintPct'))),
        _pdfCell(_num(q * v('seedPct'))),
        _pdfCell(_num(q * v('miscPct'))),
        _pdfCell(_num(q * v('shortagePct'))),
        _pdfCell(_num(q * v('seedRate'))),
        _pdfCell(_num(q * v('profExp'))),
        _pdfCell(_num(q * v('padtha'))),
        _pdfCell(_num(q * proc)),
      ]);
    }

    final paddedRows = <Map<String, dynamic>>[...rows];
    while (paddedRows.length < 10) {
      paddedRows.add({});
    }

    double q(String k) => (totals[k] ?? 0).toDouble();

    double colSum(String field) {
      double s = 0;
      for (final r in rows) {
        final qty = (r['quantityQtls'] as num?)?.toDouble() ?? 0;
        final v = (r[field] as num?)?.toDouble() ?? 0;
        s += qty * v;
      }
      return s;
    }

    final procSum = rows.fold<int>(
        0, (a, r) => a + ((r['procCycle'] as num?)?.toInt() ?? 7));
    final totalQty = q('quantityQtls');

    return pw.MultiPage(
      pageFormat: kLegalLandscape, // Legal landscape (14 × 8.5 in)
      margin: const pw.EdgeInsets.all(14),
      build: (context) => [
        pw.Center(
          child: pw.Text('THE COTTON CORPORATION OF INDIA LTD',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Center(
          child: pw.Text('HEAP REGISTER',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 6),

        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Crop Year: ${h['cropYear'] ?? ''}',
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Centre: ${h['centre'] ?? ''}',
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Factory: ${h['factoryName'] ?? ''}',
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Purchase Details: ${_fmtDate(h['fromDate'])} to ${_fmtDate(h['toDate'])}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text('Heap No: ${h['heapNo'] ?? ''}',
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Variety: ${h['variety'] ?? ''}',
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text('PURCHASE DETAILS',
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 3),

        pw.Table(
          border: pw.TableBorder.all(width: 0.4),
          columnWidths: mainWidths,
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                for (final hh in purchaseHeader)
                  _pdfCell(hh, bold: true, size: 6.5),
              ],
            ),
            for (int i = 0; i < paddedRows.length; i++)
              paddedRows[i].isEmpty
                  ? pw.TableRow(
                  children: [for (int j = 0; j < 13; j++) _pdfCell('')])
                  : dataRow(i, paddedRows[i]),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _pdfCell('', bold: true),
                _pdfCell('TOTAL', bold: true, left: true),
                _pdfCell(_num(q('quantityQtls')), bold: true),
                _pdfCell(_num(q('avgRate')), bold: true),
                _pdfCell(_num(q('lintPct')), bold: true),
                _pdfCell(_num(q('seedPct')), bold: true),
                _pdfCell(_num(q('miscPct'), decimals: 0), bold: true),
                _pdfCell(_num(q('shortagePct')), bold: true),
                _pdfCell(_num(q('seedRate')), bold: true),
                _pdfCell(_num(q('profExp')), bold: true),
                _pdfCell(_num(q('padtha')), bold: true),
                _pdfCell('7', bold: true),
                _pdfCell('', bold: true),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text('CALCULATION (Qty × Value per purchase row)',
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 3),

        pw.Table(
          border: pw.TableBorder.all(width: 0.4),
          columnWidths: calcWidths,
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _pdfCell('Sl.\nNo.', bold: true, size: 6.5),
                _pdfCell('Date', bold: true, size: 6.5),
                for (final hh in calcHeader)
                  _pdfCell(hh, bold: true, size: 6.5),
              ],
            ),
            for (int i = 0; i < paddedRows.length; i++)
              paddedRows[i].isEmpty
                  ? pw.TableRow(
                  children: [for (int j = 0; j < 11; j++) _pdfCell('')])
                  : calcRow(i, paddedRows[i]),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _pdfCell('', bold: true),
                _pdfCell('TOTAL', bold: true, left: true),
                _pdfCell(_num(colSum('avgRate')), bold: true),
                _pdfCell(_num(colSum('lintPct')), bold: true),
                _pdfCell(_num(colSum('seedPct')), bold: true),
                _pdfCell(_num(colSum('miscPct')), bold: true),
                _pdfCell(_num(colSum('shortagePct')), bold: true),
                _pdfCell(_num(colSum('seedRate')), bold: true),
                _pdfCell(_num(colSum('profExp')), bold: true),
                _pdfCell(_num(colSum('padtha')), bold: true),
                _pdfCell('$procSum', bold: true),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 10),

        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SUMMARY',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              _pdfSummaryLine('1) Total Quantity of Kapas in the Heap:',
                  '${_num(totalQty)}  Qtls'),
              _pdfSummaryLine('2) Avg. Rate (weighted):', _num(q('avgRate'))),
              _pdfSummaryLine('3) Avg. Lint % (weighted):', _num(q('lintPct'))),
              _pdfSummaryLine('4) Avg. Seed % (weighted):', _num(q('seedPct'))),
              _pdfSummaryLine('5) Misc %:', '0'),
              _pdfSummaryLine(
                  '6) Avg. Shortage % (weighted):', _num(q('shortagePct'))),
              _pdfSummaryLine(
                  '7) Avg. Seed Rate (weighted):', _num(q('seedRate'))),
              _pdfSummaryLine(
                  '8) Avg. Prof. Exp. (weighted):', _num(q('profExp'))),
              _pdfSummaryLine('9) Avg. Padtha (weighted):', _num(q('padtha'))),
              _pdfSummaryLine('10) Proc. Cycle:', '7'),
            ],
          ),
        ),

        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Signature of the Factory Incharge',
                style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Signature of the Centre Incharge',
                style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfSummaryLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 240,
            child:
            pw.Text(label, style: const pw.TextStyle(fontSize: 8.5)),
          ),
          pw.Text(':  ', style: const pw.TextStyle(fontSize: 8.5)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  // ============================================================
  // EXCEL EXPORT
  // ============================================================
  Future<void> _exportExcel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final excel = excel_lib.Excel.createExcel();
      final sheet = ExportHelper.newSheet(excel, 'Heap Register');

      final h = widget.heapData;
      final centre = (h['centre'] ?? '').toString();
      final heapNo = (h['heapNo'] ?? '').toString();
      final variety = (h['variety'] ?? '').toString();
      final factory = (h['factoryName'] ?? '').toString();
      final cropYear = (h['cropYear'] ?? '').toString();

      sheet.appendRow(['THE COTTON CORPORATION OF INDIA LTD']);
      sheet.appendRow(['HEAP REGISTER']);
      sheet.appendRow([]);
      sheet.appendRow(['Crop Year: $cropYear', '', '', 'Centre: $centre']);
      sheet.appendRow(['Factory: $factory', '', '', 'Heap No: $heapNo']);
      sheet.appendRow([
        'Purchase Details: ${_fmtDate(h['fromDate'])} to ${_fmtDate(h['toDate'])}',
        '',
        '',
        'Variety: $variety',
      ]);
      sheet.appendRow([]);

      sheet.appendRow([
        'Sl. No.',
        'Date of Purchase',
        'Quantity Qtls.',
        'Avg. Rate',
        'Lint %',
        'Seed %',
        'Misc %',
        'Shortage %',
        'Seed Rate',
        'Prof. Exp.',
        'Padtha',
        'Proc. Cycle',
        'Ceiling',
      ]);

      for (int i = 0; i < _rows.length; i++) {
        final r = _rows[i];
        sheet.appendRow([
          '${i + 1}',
          _fmtDate(r['date']),
          (r['quantityQtls'] as num?)?.toDouble() ?? 0,
          (r['avgRate'] as num?)?.toDouble() ?? 0,
          (r['lintPct'] as num?)?.toDouble() ?? 0,
          (r['seedPct'] as num?)?.toDouble() ?? 0,
          (r['miscPct'] as num?)?.toDouble() ?? 0,
          (r['shortagePct'] as num?)?.toDouble() ?? 0,
          (r['seedRate'] as num?)?.toDouble() ?? 0,
          (r['profExp'] as num?)?.toDouble() ?? 0,
          (r['padtha'] as num?)?.toDouble() ?? 0,
          (r['procCycle'] as num?)?.toInt() ?? 7,
          'MSP',
        ]);
      }

      final t = _totals;
      sheet.appendRow([
        '',
        'TOTAL',
        t['quantityQtls'],
        t['avgRate'],
        t['lintPct'],
        t['seedPct'],
        t['miscPct'],
        t['shortagePct'],
        t['seedRate'],
        t['profExp'],
        t['padtha'],
        7,
        '',
      ]);

      sheet.appendRow([]);
      sheet.appendRow(['SUMMARY']);
      sheet.appendRow(
          ['1) Total Quantity of Kapas in the Heap:', t['quantityQtls']]);
      sheet.appendRow(['2) Avg. Rate (weighted):', t['avgRate']]);
      sheet.appendRow(['3) Avg. Lint % (weighted):', t['lintPct']]);
      sheet.appendRow(['4) Avg. Seed % (weighted):', t['seedPct']]);
      sheet.appendRow(['5) Misc %:', 0]);
      sheet.appendRow(['6) Avg. Shortage % (weighted):', t['shortagePct']]);
      sheet.appendRow(['7) Avg. Seed Rate (weighted):', t['seedRate']]);
      sheet.appendRow(['8) Avg. Prof. Exp. (weighted):', t['profExp']]);
      sheet.appendRow(['9) Avg. Padtha (weighted):', t['padtha']]);
      sheet.appendRow(['10) Proc. Cycle:', 7]);

      final fileName =
          'Heap_${ExportHelper.safe(centre)}_Heap${ExportHelper.safe(heapNo)}_${ExportHelper.today()}.xlsx';
      final path = await ExportHelper.saveExcel(excel, fileName);

      messenger.showSnackBar(SnackBar(
        content: Text(path != null
            ? '✅ Exported to: $path'
            : '❌ Could not save file'),
        backgroundColor: path != null ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('❌ Error exporting: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }
}

// ============================================================
// ON-SCREEN REPORT WIDGET
// ============================================================
class _HeapReportCard extends StatelessWidget {
  final Map<String, dynamic> heapData;
  final List<Map<String, dynamic>> rows;
  final Map<String, double> totals;

  const _HeapReportCard({
    required this.heapData,
    required this.rows,
    required this.totals,
  });

  static String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      return DateFormat('dd.MM.yyyy').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return '';
    }
  }

  static String _num(dynamic v, {int decimals = 2}) {
    if (v == null) return '0';
    final d = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    final centre = (heapData['centre'] ?? '').toString().toUpperCase();
    final heapNo = (heapData['heapNo'] ?? '').toString();
    final variety = (heapData['variety'] ?? '').toString();
    final factory = (heapData['factoryName'] ?? '').toString();
    final cropYear = (heapData['cropYear'] ?? '').toString();
    final fromDate = _fmtDate(heapData['fromDate']);
    final toDate = _fmtDate(heapData['toDate']);

    final paddedRows = <Map<String, dynamic>>[...rows];
    while (paddedRows.length < 10) {
      paddedRows.add({});
    }

    double q(String k) => (totals[k] ?? 0).toDouble();

    double colSum(String field) {
      double s = 0;
      for (final r in rows) {
        final qty = (r['quantityQtls'] as num?)?.toDouble() ?? 0;
        final v = (r[field] as num?)?.toDouble() ?? 0;
        s += qty * v;
      }
      return s;
    }

    final procSum = rows.fold<int>(
        0, (a, r) => a + ((r['procCycle'] as num?)?.toInt() ?? 7));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF94A3B8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _titleBlock(),
          _metaBlock(
            cropYear: cropYear,
            centre: centre,
            factory: factory,
            fromDate: fromDate,
            toDate: toDate,
            heapNo: heapNo,
            variety: variety,
          ),
          _buildPurchaseTable(paddedRows),
          const SizedBox(height: 6),
          _buildCalculationTable(paddedRows, colSum, procSum),
          const SizedBox(height: 10),
          _buildSummaryBlock(q),
          const SizedBox(height: 10),
          _buildSignatures(),
        ],
      ),
    );
  }

  Widget _titleBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF94A3B8))),
      ),
      child: Column(
        children: const [
          Text('THE COTTON CORPORATION OF INDIA LTD',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          SizedBox(height: 2),
          Text('HEAP REGISTER',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _metaBlock({
    required String cropYear,
    required String centre,
    required String factory,
    required String fromDate,
    required String toDate,
    required String heapNo,
    required String variety,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF94A3B8))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _metaCell('Crop Year', cropYear)),
              Expanded(child: _metaCell('Centre', centre)),
              Expanded(child: _metaCell('Factory', factory)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                  child: _metaCell('Purchase Details', '$fromDate to $toDate')),
              Expanded(child: _metaCell('Heap No.', heapNo)),
              Expanded(child: _metaCell('Variety', variety)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaCell(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569))),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  static const List<String> _purchaseHeaders = [
    'Sl.\nNo.',
    'Date of\nPurchase',
    'Qty\nQtls.',
    'Avg.\nRate',
    'Lint %',
    'Seed %',
    'Misc %',
    'Short.\n%',
    'Seed\nRate',
    'Prof.\nExp.',
    'Padtha',
    'Proc.\nCycle',
    'Ceiling',
  ];

  static const List<double> _purchaseWidths = [
    32, 76, 62, 62, 50, 50, 46, 54, 54, 58, 62, 48, 54,
  ];

  Widget _buildPurchaseTable(List<Map<String, dynamic>> paddedRows) {
    return _scrollableTable(
      headers: _purchaseHeaders,
      widths: _purchaseWidths,
      rowCount: paddedRows.length,
      builder: (i) {
        final r = paddedRows[i];
        if (r.isEmpty) {
          return List.generate(_purchaseHeaders.length, (_) => '');
        }
        final qty = (r['quantityQtls'] as num?)?.toDouble() ?? 0;
        return [
          '${i + 1}',
          _fmtDate(r['date']),
          _num(qty),
          _num(r['avgRate']),
          _num(r['lintPct']),
          _num(r['seedPct']),
          _num(r['miscPct'] ?? 0, decimals: 0),
          _num(r['shortagePct']),
          _num(r['seedRate']),
          _num(r['profExp']),
          _num(r['padtha']),
          '${(r['procCycle'] as num?)?.toInt() ?? 7}',
          (r['ceiling'] ?? 'MSP').toString(),
        ];
      },
      totalsRow: [
        '',
        'TOTAL',
        _num(totals['quantityQtls']),
        _num(totals['avgRate']),
        _num(totals['lintPct']),
        _num(totals['seedPct']),
        '0',
        _num(totals['shortagePct']),
        _num(totals['seedRate']),
        _num(totals['profExp']),
        _num(totals['padtha']),
        '7',
        '',
      ],
    );
  }

  static const List<String> _calcHeaders = [
    'Sl.\nNo.',
    'Date',
    'Qty ×\nAvg',
    'Qty ×\nLint',
    'Qty ×\nSeed',
    'Qty ×\nMisc',
    'Qty ×\nShort',
    'Qty ×\nSeed\nRate',
    'Qty ×\nProf\nExp',
    'Qty ×\nPadtha',
    'Qty ×\nProc',
  ];

  static const List<double> _calcWidths = [
    32, 76, 74, 68, 68, 66, 74, 74, 74, 74, 66,
  ];

  Widget _buildCalculationTable(
      List<Map<String, dynamic>> paddedRows,
      double Function(String) colSum,
      int procSum,
      ) {
    return _scrollableTable(
      headers: _calcHeaders,
      widths: _calcWidths,
      rowCount: paddedRows.length,
      builder: (i) {
        final r = paddedRows[i];
        if (r.isEmpty) {
          return List.generate(_calcHeaders.length, (_) => '');
        }
        final q = (r['quantityQtls'] as num?)?.toDouble() ?? 0;
        double v(String k) => (r[k] as num?)?.toDouble() ?? 0;
        final proc = (r['procCycle'] as num?)?.toInt() ?? 7;
        return [
          '${i + 1}',
          _fmtDate(r['date']),
          _num(q * v('avgRate')),
          _num(q * v('lintPct')),
          _num(q * v('seedPct')),
          _num(q * v('miscPct')),
          _num(q * v('shortagePct')),
          _num(q * v('seedRate')),
          _num(q * v('profExp')),
          _num(q * v('padtha')),
          _num(q * proc),
        ];
      },
      totalsRow: [
        '',
        'TOTAL',
        _num(colSum('avgRate')),
        _num(colSum('lintPct')),
        _num(colSum('seedPct')),
        _num(colSum('miscPct')),
        _num(colSum('shortagePct')),
        _num(colSum('seedRate')),
        _num(colSum('profExp')),
        _num(colSum('padtha')),
        '$procSum',
      ],
    );
  }

  Widget _scrollableTable({
    required List<String> headers,
    required List<double> widths,
    required int rowCount,
    required List<String> Function(int) builder,
    required List<String> totalsRow,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF94A3B8)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: const Color(0xFFE2E8F0),
              child: Row(
                children: [
                  for (int i = 0; i < headers.length; i++)
                    _cell(headers[i],
                        width: widths[i], bold: true, header: true),
                ],
              ),
            ),
            for (int r = 0; r < rowCount; r++)
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    for (int i = 0; i < headers.length; i++)
                      _cell(builder(r)[i], width: widths[i]),
                  ],
                ),
              ),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                border: Border(
                  top: BorderSide(color: Color(0xFF94A3B8), width: 1),
                ),
              ),
              child: Row(
                children: [
                  for (int i = 0; i < headers.length; i++)
                    _cell(totalsRow[i], width: widths[i], bold: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(
      String text, {
        required double width,
        bool bold = false,
        bool header = false,
      }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      alignment: header ? Alignment.center : Alignment.centerRight,
      child: Text(
        text,
        textAlign: header ? TextAlign.center : TextAlign.right,
        style: TextStyle(
          fontSize: header ? 9 : 10,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildSummaryBlock(double Function(String) q) {
    Widget line(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 260,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF475569))),
            ),
            const Text(':  ',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600)),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF94A3B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('SUMMARY',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          line('1) Total Quantity of Kapas in the Heap:',
              '${_num(q('quantityQtls'))}  Qtls'),
          line('2) Avg. Rate (weighted):', _num(q('avgRate'))),
          line('3) Avg. Lint % (weighted):', _num(q('lintPct'))),
          line('4) Avg. Seed % (weighted):', _num(q('seedPct'))),
          line('5) Misc %:', '0'),
          line('6) Avg. Shortage % (weighted):', _num(q('shortagePct'))),
          line('7) Avg. Seed Rate (weighted):', _num(q('seedRate'))),
          line('8) Avg. Prof. Exp. (weighted):', _num(q('profExp'))),
          line('9) Avg. Padtha (weighted):', _num(q('padtha'))),
          line('10) Proc. Cycle:', '7'),
        ],
      ),
    );
  }

  Widget _buildSignatures() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text('Signature of the Factory Incharge',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          Text('Signature of the Centre Incharge',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}