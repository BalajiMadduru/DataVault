import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/apiservice.dart';

class ProformaViewScreen extends StatefulWidget {
  final String purchaseEntryId;
  final String proformaId;
  // If provided (e.g. from a filtered list screen), this data is used
  // directly instead of re-fetching the full, unfiltered document by ID.
  final Map<String, dynamic>? initialData;

  const ProformaViewScreen({
    super.key,
    this.purchaseEntryId = '',
    this.proformaId = '',
    this.initialData,
  });

  @override
  State<ProformaViewScreen> createState() => _ProformaViewScreenState();
}

// ============================================================
// Row model - every derived value is computed in ONE place
// ============================================================
class _Row {
  final String? label; // overrides the date cell (used for PROG. AVG.)
  final DateTime? date;
  final String centre;
  final String factory;
  final String variety;
  final double qty;
  final double rate;
  final double amount; // qty * rate
  final double farmers;
  final double moisture;
  final double moistureValue; // qty * moisture
  final double shortage;
  final double shortageValue; // qty * shortage
  final double padtha;
  final double padthaValue; // qty * padtha
  final double lint;
  final double lintValue; // qty * lint
  final double seed; // 100 - lint - shortage
  final double seedValue; // qty * seed
  final double bales;

  const _Row({
    this.label,
    this.date,
    required this.centre,
    required this.factory,
    required this.variety,
    required this.qty,
    required this.rate,
    required this.amount,
    required this.farmers,
    required this.moisture,
    required this.moistureValue,
    required this.shortage,
    required this.shortageValue,
    required this.padtha,
    required this.padthaValue,
    required this.lint,
    required this.lintValue,
    required this.seed,
    required this.seedValue,
    required this.bales,
  });
}

class _Col {
  final String label;
  final double width;
  final bool numeric;
  final bool highlight;
  final String Function(_Row r) cell;

  const _Col(this.label, this.width, this.cell,
      {this.numeric = true, this.highlight = false});
}

String _fmt(double v) => v.toStringAsFixed(2);

String _fmtQty(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

// Column order follows the requested field list.
final List<_Col> _cols = [
  _Col('DATE', 90,
          (r) => r.label ??
          (r.date != null ? DateFormat('dd/MM/yyyy').format(r.date!) : ''),
      numeric: false),
  _Col('CENTRE', 90, (r) => r.centre, numeric: false),
  _Col('FACTORY', 110, (r) => r.factory, numeric: false),
  _Col('VARIETY', 90, (r) => r.variety, numeric: false),
  _Col('QUANTITY', 80, (r) => _fmtQty(r.qty)),
  _Col('RATE', 75, (r) => _fmt(r.rate)),
  _Col('AMOUNT', 95, (r) => _fmt(r.amount)),
  _Col('FARMERS', 70, (r) => _fmtQty(r.farmers)),
  _Col('MOISTURE', 75, (r) => _fmt(r.moisture)),
  _Col('MOISTURE VALUE', 100, (r) => _fmt(r.moistureValue)),
  _Col('SHORTAGE', 75, (r) => _fmt(r.shortage)),
  _Col('SHORTAGE VALUE', 100, (r) => _fmt(r.shortageValue)),
  _Col('PADTHA', 70, (r) => _fmt(r.padtha)),
  _Col('PADTHA VALUE', 95, (r) => _fmt(r.padthaValue)),
  _Col('LINT', 65, (r) => _fmt(r.lint)),
  _Col('LINT VALUE', 90, (r) => _fmt(r.lintValue)),
  _Col('SEED', 65, (r) => _fmt(r.seed)),
  _Col('SEED VALUE', 95, (r) => _fmt(r.seedValue), highlight: true),
  _Col('BALES', 65, (r) => _fmtQty(r.bales)),
];

class _ProformaViewScreenState extends State<ProformaViewScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _proformaData;
  // Purchase entries keyed by document id - source of Lint, Shortage,
  // Moisture and Padtha budget values.
  Map<String, Map<String, dynamic>> _purchaseById = {};
  String? _error;
  final ScrollController _tableScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProforma();
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPurchaseEntries() async {
    try {
      final response = await ApiService.getPurchaseEntries();
      if (response.success && response.data != null) {
        final list = response.data!['entries'] as List? ?? [];
        final map = <String, Map<String, dynamic>>{};
        for (final item in list) {
          final m = Map<String, dynamic>.from(item as Map);
          final id = m['id']?.toString();
          if (id != null) map[id] = m;
        }
        _purchaseById = map;
      }
    } catch (_) {
      // Non-fatal: rows fall back to the values stored on the proforma entry.
      _purchaseById = {};
    }
  }

  Future<void> _loadProforma() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _loadPurchaseEntries();
    if (!mounted) return;

    if (widget.initialData != null) {
      setState(() {
        _proformaData = widget.initialData;
        _isLoading = false;
      });
      return;
    }

    ApiResponse response;

    if (widget.proformaId.isNotEmpty) {
      response = await ApiService.getProformaById(widget.proformaId);
    } else if (widget.purchaseEntryId.isNotEmpty) {
      response =
      await ApiService.getProformaByPurchaseEntry(widget.purchaseEntryId);
    } else {
      setState(() {
        _error = 'No proforma ID or purchase entry ID provided';
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;

    if (response.success && response.data != null) {
      setState(() {
        _proformaData = response.data!['proforma'] as Map<String, dynamic>;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.message;
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // Calculation
  // ============================================================

  double _n(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  /// First candidate that is a real number (null/empty are skipped).
  double _pick(List<dynamic> candidates) {
    for (final c in candidates) {
      if (c == null) continue;
      if (c is num) return c.toDouble();
      if (c is String) {
        final p = double.tryParse(c);
        if (p != null) return p;
      }
    }
    return 0;
  }

  _Row _buildRow(
      String purchaseId,
      Map<String, dynamic> e,
      Map<String, dynamic> doc,
      ) {
    final p = _purchaseById[purchaseId];

    final qty = _n(e['quantity']);
    final rate = _n(e['rate']);
    final farmers = _pick([e['farmers'], p?['farmersDay']]);

    final moisture = _pick([e['moisture'], p?['moisture']]);
    final padtha = _pick([e['padtha'], p?['budgetedPadtha']]);

    // Lint & Shortage come from the purchase entry (budgeted values).
    final lint = _pick([p?['budgetedLint'], e['lint']]);
    final shortage = _pick([p?['budgetedShortage'], e['shortage']]);
    final seed = 100 - lint - shortage;

    return _Row(
      date: DateTime.tryParse(e['entryDate']?.toString() ?? ''),
      centre: (e['centre'] ?? doc['centre'] ?? '').toString(),
      factory: (e['factory'] ?? e['factoryName'] ?? '').toString(),
      variety: (e['variety'] ?? doc['variety'] ?? '').toString(),
      qty: qty,
      rate: rate,
      amount: qty * rate,
      farmers: farmers,
      moisture: moisture,
      moistureValue: qty * moisture,
      shortage: shortage,
      shortageValue: qty * shortage,
      padtha: padtha,
      padthaValue: qty * padtha,
      lint: lint,
      lintValue: qty * lint,
      seed: seed,
      seedValue: qty * seed,
      bales: _n(e['bales']),
    );
  }

  List<_Row> _buildRows(Map<String, dynamic> doc) {
    final entries = doc['entries'] as Map<String, dynamic>? ?? {};
    final rows = <_Row>[];
    entries.forEach((id, value) {
      if (value is Map) {
        rows.add(_buildRow(id, Map<String, dynamic>.from(value), doc));
      }
    });
    rows.sort((a, b) {
      if (a.date == null || b.date == null) return 0;
      return a.date!.compareTo(b.date!);
    });
    return rows;
  }

  /// PROG. AVG. row: sums for quantities/values, weighted averages
  /// (value / total quantity) for rate, moisture, shortage, etc.
  _Row _buildProgAvg(List<_Row> rows, Map<String, dynamic> doc) {
    double sum(double Function(_Row r) f) =>
        rows.fold(0.0, (a, r) => a + f(r));

    final qty = sum((r) => r.qty);
    final amount = sum((r) => r.amount);
    final moistureValue = sum((r) => r.moistureValue);
    final shortageValue = sum((r) => r.shortageValue);
    final padthaValue = sum((r) => r.padthaValue);
    final lintValue = sum((r) => r.lintValue);
    final seedValue = sum((r) => r.seedValue);
    double avg(double v) => qty > 0 ? v / qty : 0;

    return _Row(
      label: 'PROG. AVG.',
      centre: (doc['centre'] ?? '').toString(),
      factory: '',
      variety: (doc['variety'] ?? '').toString(),
      qty: qty,
      rate: avg(amount),
      amount: amount,
      farmers: sum((r) => r.farmers),
      moisture: avg(moistureValue),
      moistureValue: moistureValue,
      shortage: avg(shortageValue),
      shortageValue: shortageValue,
      padtha: avg(padthaValue),
      padthaValue: padthaValue,
      lint: avg(lintValue),
      lintValue: lintValue,
      seed: avg(seedValue),
      seedValue: seedValue,
      bales: sum((r) => r.bales),
    );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proforma Report'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _proformaData != null ? () => _exportToExcel() : null,
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProforma,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _buildProformaContent(),
    );
  }

  // ============================================================
  // Excel export
  // ============================================================

  Future<void> _exportToExcel() async {
    if (_proformaData == null) return;

    try {
      final excel = excel_lib.Excel.createExcel();
      final sheet = excel['Proforma'];

      final data = _proformaData!;
      final centre = data['centre'] ?? '';
      final variety = data['variety'] ?? '';
      final rows = _buildRows(data);
      final progAvg = _buildProgAvg(rows, data);

      sheet.appendRow(
          ['THE COTTON CORPORATION OF INDIA LTD :: BRANCH OFFICE HUBLI']);
      sheet.appendRow([]);
      sheet.appendRow([
        'PROFORMA FOR KAPAS PURCHASE',
        'CENTRE: $centre',
        'VARIETY: $variety',
      ]);
      sheet.appendRow([]);

      sheet.appendRow(_cols.map((c) => c.label).toList());
      for (final r in rows) {
        sheet.appendRow(_cols.map((c) => c.cell(r)).toList());
      }
      sheet.appendRow(_cols.map((c) => c.cell(progAvg)).toList());

      sheet.appendRow([]);
      sheet.appendRow([
        'Total Seed Value',
        ...List.filled(_cols.length - 3, ''),
        '₹${_fmt(progAvg.seedValue)}',
      ]);

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final fileName =
            'Proforma_${centre}_${variety}_${DateFormat('ddMMyyyy').format(DateTime.now())}.xlsx';
        String? savePath;

        if (Platform.isAndroid || Platform.isIOS) {
          final directory = await getExternalStorageDirectory();
          if (directory != null) savePath = '${directory.path}/$fileName';
        } else {
          final directory = await getApplicationDocumentsDirectory();
          savePath = '${directory.path}/$fileName';
        }

        if (savePath != null) {
          await File(savePath).writeAsBytes(fileBytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Proforma exported to: $fileName'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error exporting proforma: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // UI
  // ============================================================

  Widget _headerStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 40,
    margin: const EdgeInsets.symmetric(horizontal: 24),
    color: const Color(0xFFE2E8F0),
  );

  Widget _buildProformaContent() {
    final data = _proformaData!;
    final centre = (data['centre'] ?? '').toString();
    final variety = (data['variety'] ?? '').toString();
    final rows = _buildRows(data);
    final progAvg = _buildProgAvg(rows, data);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    const Text(
                      'PROFORMA FOR KAPAS PURCHASE',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _headerStat(
                              'CENTRE', centre.isNotEmpty ? centre : 'N/A'),
                          _divider(),
                          _headerStat(
                              'VARIETY', variety.isNotEmpty ? variety : 'N/A'),
                          _divider(),
                          _headerStat('ENTRIES', '${rows.length}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Icon(Icons.swipe, size: 14, color: Color(0xFF94A3B8)),
                  SizedBox(width: 4),
                  Text(
                    'Scroll to see all fields',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Scrollbar(
                  controller: _tableScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildProformaTable(rows, progAvg),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildProgAvgSummary(progAvg),
              const SizedBox(height: 8),
              Text(
                'Total Entries: ${rows.length}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(_Col col, String text,
      {bool header = false, bool bold = false, Color? color}) {
    return Container(
      width: col.width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: (header || bold) ? FontWeight.bold : FontWeight.normal,
          color: color ?? const Color(0xFF0F172A),
        ),
        textAlign: col.numeric ? TextAlign.right : TextAlign.center,
      ),
    );
  }

  Widget _buildProformaTable(List<_Row> rows, _Row progAvg) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Container(
          color: const Color(0xFFF1F5F9),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: _cols.map((c) => _cell(c, c.label, header: true)).toList(),
          ),
        ),

        // Data rows
        ...rows.map((r) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
              ),
            ),
            child: Row(
              children: _cols
                  .map((c) => _cell(
                c,
                c.cell(r),
                bold: c.highlight,
                color: c.highlight ? const Color(0xFF059669) : null,
              ))
                  .toList(),
            ),
          );
        }),

        // PROG. AVG. row (inside the table)
        Container(
          color: const Color(0xFFF1F5F9),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: _cols
                .map((c) => _cell(
              c,
              c.cell(progAvg),
              bold: true,
              color: c.highlight ? const Color(0xFF059669) : null,
            ))
                .toList(),
          ),
        ),
      ],
    );
  }

  // PROG. AVG. summary card shown below the table.
  Widget _buildProgAvgSummary(_Row progAvg) {
    // Text-only columns (date/centre/factory/variety/heap) aren't averaged.
    final items = _cols.where((c) => c.numeric).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROG. AVG.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: items.map((c) {
              final value = c.cell(progAvg);
              return SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.highlight ? '₹$value' : value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: c.highlight
                            ? const Color(0xFF4ADE80)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}