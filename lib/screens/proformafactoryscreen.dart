import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_lib;
import '../services/apiservice.dart';
import '../services/ExportHelper.java';

// ============================================================
// Proforma - Factory wise
// Built on the fly from purchase entries (each entry carries a
// `factories` list with progressive qtls/bales per factory).
// Daily factory quantity = today's progressive - previous progressive
// for the same centre + variety + factory.
// ============================================================

class _FRow {
  final String? label;
  final DateTime? date;
  final String centre;
  final String factory;
  final String variety;
  final double qty, rate, amount;
  final double farmers;
  final double moisture, moistureValue;
  final double seedRate, seedRateValue;
  final double proforma, proformaValue;
  final double shortage, shortageValue;
  final double padtha, padthaValue;
  final double lint, lintValue;
  final double seed, seedValue;
  final double bales;

  const _FRow({
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
    required this.seedRate,
    required this.seedRateValue,
    required this.proforma,
    required this.proformaValue,
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

class _FGroup {
  final String factory;
  final String variety;
  final List<_FRow> rows = [];
  _FGroup(this.factory, this.variety);
}

class _FCol {
  final String label;
  final double width;
  final bool numeric;
  final bool highlight;
  final String Function(_FRow r) cell;
  const _FCol(this.label, this.width, this.cell,
      {this.numeric = true, this.highlight = false});
}

String _f2(double v) => v.toStringAsFixed(2);
String _fq(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

final List<_FCol> _fCols = [
  _FCol(
      'DATE',
      90,
          (r) =>
      r.label ??
          (r.date != null ? DateFormat('dd/MM/yyyy').format(r.date!) : ''),
      numeric: false),
  _FCol('CENTRE', 90, (r) => r.centre, numeric: false),
  _FCol('FACTORY', 120, (r) => r.factory, numeric: false),
  _FCol('VARIETY', 90, (r) => r.variety, numeric: false),
  _FCol('QUANTITY', 80, (r) => _fq(r.qty)),
  _FCol('RATE', 75, (r) => _f2(r.rate)),
  _FCol('AMOUNT', 95, (r) => _f2(r.amount)),
  _FCol('FARMERS', 70, (r) => _fq(r.farmers)),
  _FCol('MOISTURE', 75, (r) => _f2(r.moisture)),
  _FCol('MOISTURE VALUE', 100, (r) => _f2(r.moistureValue)),
  _FCol('SHORTAGE', 75, (r) => _f2(r.shortage)),
  _FCol('SHORTAGE VALUE', 100, (r) => _f2(r.shortageValue)),
  _FCol('SEED RATE', 75, (r) => _f2(r.seedRate)),
  _FCol('SEED RATE VALUE', 105, (r) => _f2(r.seedRateValue)),
  _FCol('PROFORMA', 75, (r) => _f2(r.proforma)),
  _FCol('PROFORMA VALUE', 105, (r) => _f2(r.proformaValue)),
  _FCol('PADTHA', 70, (r) => _f2(r.padtha)),
  _FCol('PADTHA VALUE', 95, (r) => _f2(r.padthaValue)),
  _FCol('LINT', 65, (r) => _f2(r.lint)),
  _FCol('LINT VALUE', 90, (r) => _f2(r.lintValue)),
  _FCol('SEED', 65, (r) => _f2(r.seed)),
  _FCol('SEED VALUE', 95, (r) => _f2(r.seedValue), highlight: true),
  _FCol('BALES', 65, (r) => _fq(r.bales)),
];

double _n(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

_FRow _progAvg(List<_FRow> rows, String centre, String variety) {
  double sum(double Function(_FRow r) f) => rows.fold(0.0, (a, r) => a + f(r));
  final qty = sum((r) => r.qty);
  double avg(double v) => qty > 0 ? v / qty : 0;
  final amount = sum((r) => r.amount);
  final mv = sum((r) => r.moistureValue);
  final srv = sum((r) => r.seedRateValue);
  final prv = sum((r) => r.proformaValue);
  final sv = sum((r) => r.shortageValue);
  final pv = sum((r) => r.padthaValue);
  final lv = sum((r) => r.lintValue);
  final sdv = sum((r) => r.seedValue);
  return _FRow(
    label: 'PROG. AVG.',
    centre: centre,
    factory: '',
    variety: variety,
    qty: qty,
    rate: avg(amount),
    amount: amount,
    farmers: sum((r) => r.farmers),
    moisture: avg(mv),
    moistureValue: mv,
    seedRate: avg(srv),
    seedRateValue: srv,
    proforma: avg(prv),
    proformaValue: prv,
    shortage: avg(sv),
    shortageValue: sv,
    padtha: avg(pv),
    padthaValue: pv,
    lint: avg(lv),
    lintValue: lv,
    seed: avg(sdv),
    seedValue: sdv,
    bales: sum((r) => r.bales),
  );
}

/// Turns purchase entries into factory + variety groups.
///
/// Grouping is case-insensitive on both factory name and variety, so entries
/// that differ only in casing (e.g. "Balu" vs "balu") are merged into a
/// single report. The first spelling seen is kept as the display name.
List<_FGroup> _buildGroups(List<Map<String, dynamic>> entries) {
  entries.sort((a, b) {
    final da = DateTime.tryParse(a['date']?.toString() ?? '');
    final db = DateTime.tryParse(b['date']?.toString() ?? '');
    if (da == null || db == null) return 0;
    return da.compareTo(db);
  });

  final lastProg = <String, List<double>>{}; // key -> [qtls, bales]
  final groups = <String, _FGroup>{};

  for (final e in entries) {
    final factories = e['factories'];
    if (factories is! List || factories.isEmpty) continue;

    final centre = (e['centre'] ?? '').toString();
    final variety = (e['variety'] ?? '').toString().trim();
    final varietyKey = variety.toLowerCase();

    final date = DateTime.tryParse(e['date']?.toString() ?? '');
    final rate = _n(e['avgKapasRate']);
    final entryMoisture = _n(e['moisture']);
    final entrySeedRate = _n(e['cottonSeedRate']);
    final proforma = _n(e['proformaExpenses']);
    final lint = _n(e['budgetedLint']);
    final shortage = _n(e['budgetedShortage']);
    final padtha = _n(e['budgetedPadtha']);
    final seed = 100 - lint - shortage;

    for (final f in factories) {
      if (f is! Map) continue;

      final nameRaw = (f['factoryName'] ?? '').toString().trim();
      if (nameRaw.isEmpty) continue;

      // Case-insensitive keys for both factory and variety, so entries
      // that differ only in casing collapse into one group.
      final nameKey = nameRaw.toLowerCase();
      final groupKey = '$nameKey|$varietyKey';
      final progKey = '$centre|$varietyKey|$nameKey';

      // Per-factory inputs; fall back to the entry-level value for older
      // entries saved before these fields existed.
      final farmers = _n(f['farmers']);
      final fMoisture = _n(f['moisture']);
      final moisture = fMoisture > 0 ? fMoisture : entryMoisture;
      final fSeedRate = _n(f['seedRate']);
      final seedRate = fSeedRate > 0 ? fSeedRate : entrySeedRate;

      final progQ = _n(f['progPurchaseQtls']);
      final progB = _n(f['progPurchaseBales']);
      final prev = lastProg[progKey] ?? [0, 0];
      // If progressive went down (reset), treat current value as day's qty.
      final qty = progQ >= prev[0] ? progQ - prev[0] : progQ;
      final bales = progB >= prev[1] ? progB - prev[1] : progB;
      lastProg[progKey] = [progQ, progB];

      // Create the group on first sight; keep the first spelling seen.
      final g = groups.putIfAbsent(
        groupKey,
            () => _FGroup(nameRaw, variety),
      );

      g.rows.add(_FRow(
        date: date,
        centre: centre,
        factory: nameRaw,
        variety: variety,
        qty: qty,
        rate: rate,
        amount: qty * rate,
        farmers: farmers,
        moisture: moisture,
        moistureValue: qty * moisture,
        seedRate: seedRate,
        seedRateValue: qty * seedRate,
        proforma: proforma,
        proformaValue: qty * proforma,
        shortage: shortage,
        shortageValue: qty * shortage,
        padtha: padtha,
        padthaValue: qty * padtha,
        lint: lint,
        lintValue: qty * lint,
        seed: seed,
        seedValue: qty * seed,
        bales: bales,
      ));
    }
  }

  final list = groups.values.toList()
    ..sort((a, b) {
      final f = a.factory.toLowerCase().compareTo(b.factory.toLowerCase());
      if (f != 0) return f;
      return a.variety.toLowerCase().compareTo(b.variety.toLowerCase());
    });
  return list;
}

// ============================================================
// LIST SCREEN
// ============================================================

class ProformaFactoryListScreen extends StatefulWidget {
  const ProformaFactoryListScreen({super.key});

  @override
  State<ProformaFactoryListScreen> createState() =>
      _ProformaFactoryListScreenState();
}

class _ProformaFactoryListScreenState extends State<ProformaFactoryListScreen> {
  List<_FGroup> _groups = [];
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;
  String? _error;
  String? _factoryFilter;
  String? _varietyFilter;

  List<String> get _factories =>
      _groups.map((g) => g.factory).toSet().toList()..sort();
  List<String> get _varieties =>
      _groups.map((g) => g.variety).where((v) => v.isNotEmpty).toSet().toList()
        ..sort();

  List<_FGroup> get _filtered => _groups.where((g) {
    if (_factoryFilter != null && g.factory != _factoryFilter) return false;
    if (_varietyFilter != null && g.variety != _varietyFilter) return false;
    return true;
  }).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final response = await ApiService.getPurchaseEntries();
    if (!mounted) return;
    setState(() {
      if (response.success && response.data != null) {
        final list = (response.data!['entries'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _entries = list;
        _groups = _buildGroups(list);
      } else {
        _entries = [];
        _groups = [];
        _error = response.message;
      }
      _isLoading = false;
    });
  }

  // Fields the purchase entry form sends on save (see _buildPurchaseData).
  static const _entryFields = [
    'reportType', 'date', 'variety', 'centre', 'reportNo', 'farmersDay',
    'arrivalsBales', 'cciPurchaseQtls', 'cciPurchaseBales', 'avgKapasRate',
    'moisture', 'budgetedLint', 'budgetedShortage', 'budgetedCottonSeedPct',
    'cottonSeedRate', 'processingCycle', 'proformaExpenses', 'budgetedPadtha',
    'dayPressedBales', 'marketHighestRate', 'marketLowestRate',
    'cciHighestRate', 'cciLowestRate', 'progPressedBales',
    'progPurchaseQtls', 'progPurchaseBales', 'progFarmers',
    'otherVarietiesProgressive', 'factories',
  ];

  /// Factory-wise proforma is built from purchase entries, so deleting it
  /// removes this factory (for this variety) from those entries.
  Future<void> _deleteGroup(_FGroup g) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Factory Proforma'),
        content: Text(
            'Remove "${g.factory}" (${g.variety.isEmpty ? '—' : g.variety}) '
                'from all purchase entries?\n\n'
                'This also removes it from the Factory Wise table in those '
                'purchase reports. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    String? failure;

    for (final e in _entries) {
      if ((e['variety'] ?? '').toString() != g.variety) continue;
      final factories = e['factories'];
      if (factories is! List) continue;

      final kept = factories
          .where((f) =>
      !(f is Map &&
          (f['factoryName'] ?? '').toString().trim() == g.factory))
          .toList();
      if (kept.length == factories.length) continue;

      final id = (e['id'] ?? e['_id'])?.toString();
      if (id == null || id.isEmpty) continue;

      final data = <String, dynamic>{
        for (final k in _entryFields)
          if (e.containsKey(k)) k: e[k],
        'factories': kept,
      };
      final res = await ApiService.updateEntry(id, data);
      if (!res.success) {
        failure = res.message;
        break;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(failure ?? 'Factory proforma deleted'),
      backgroundColor: failure == null ? Colors.green : Colors.red,
    ));
    _load();
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF1F5F9),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proforma – Factory wise'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
              tooltip: 'Refresh'),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _factoryFilter,
                    isExpanded: true,
                    decoration: _dec('All Factories'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Factories')),
                      ..._factories.map(
                              (c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => setState(() => _factoryFilter = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _varietyFilter,
                    isExpanded: true,
                    decoration: _dec('All Varieties'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Varieties')),
                      ..._varieties.map(
                              (v) => DropdownMenuItem(value: v, child: Text(v))),
                    ],
                    onChanged: (v) => setState(() => _varietyFilter = v),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('❌ $_error', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                      onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
                : items.isEmpty
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No factory-wise proforma yet.\nAdd factories in a purchase entry to generate one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final g = items[i];
                final dates = g.rows
                    .map((r) => r.date)
                    .whereType<DateTime>()
                    .toList()
                  ..sort();
                final fmt = DateFormat('dd/MM/yyyy');
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFD1FAE5),
                      child: Icon(Icons.factory,
                          color: Color(0xFF0F172A)),
                    ),
                    title: Text(
                      '${g.factory} — ${g.variety.isEmpty ? '—' : g.variety}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Entries: ${g.rows.length}',
                            style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13)),
                        if (dates.isNotEmpty)
                          Text(
                            'Date range: ${fmt.format(dates.first)} → ${fmt.format(dates.last)}',
                            style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () => _deleteGroup(g),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProformaFactoryViewScreen(
                          factory: g.factory,
                          variety: g.variety,
                          rows: g.rows,
                        ),
                      ),
                    ),
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

// ============================================================
// VIEW SCREEN
// ============================================================

class ProformaFactoryViewScreen extends StatefulWidget {
  final String factory;
  final String variety;
  final List<_FRow> rows;

  const ProformaFactoryViewScreen({
    super.key,
    required this.factory,
    required this.variety,
    required this.rows,
  });

  @override
  State<ProformaFactoryViewScreen> createState() =>
      _ProformaFactoryViewScreenState();
}

class _ProformaFactoryViewScreenState extends State<ProformaFactoryViewScreen> {
  final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  // ============================================================
  // Excel export
  // ============================================================

  Future<void> _exportToExcel(List<_FRow> rows, _FRow avg) async {
    try {
      final excel = excel_lib.Excel.createExcel();
      final sheet = ExportHelper.newSheet(excel, 'Proforma');

      final factory = widget.factory;
      final variety = widget.variety;

      sheet.appendRow(
          ['THE COTTON CORPORATION OF INDIA LTD :: BRANCH OFFICE HUBLI']);
      sheet.appendRow([]);
      sheet.appendRow([
        'PROFORMA FOR KAPAS PURCHASE',
        'FACTORY: $factory',
        'VARIETY: $variety',
      ]);
      sheet.appendRow([]);

      sheet.appendRow(_fCols.map((c) => c.label).toList());
      for (final r in rows) {
        sheet.appendRow(_fCols.map((c) => c.cell(r)).toList());
      }
      sheet.appendRow(_fCols.map((c) => c.cell(avg)).toList());

      sheet.appendRow([]);
      sheet.appendRow([
        'Total Seed Value',
        ...List.filled(_fCols.length - 3, ''),
        '₹${_f2(avg.seedValue)}',
      ]);

      final fileName =
          'Proforma_Factory_${ExportHelper.safe(factory)}_${ExportHelper.safe(variety)}_${ExportHelper.today()}.xlsx';
      final path = await ExportHelper.saveExcel(excel, fileName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(path != null
            ? '✅ Proforma exported to: $path'
            : '❌ Could not save the file'),
        backgroundColor: path != null ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Error exporting proforma: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _cell(_FCol c, String t,
      {bool header = false, bool bold = false, Color? color}) {
    return Container(
      width: c.width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        t,
        style: TextStyle(
          fontSize: 10,
          fontWeight: (header || bold) ? FontWeight.bold : FontWeight.normal,
          color: color ?? const Color(0xFF0F172A),
        ),
        textAlign: c.numeric ? TextAlign.right : TextAlign.center,
      ),
    );
  }

  Widget _stat(String l, String v) => Column(
    children: [
      Text(l,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B))),
      const SizedBox(height: 2),
      Text(v,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A))),
    ],
  );

  Widget _vDivider() => Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      color: const Color(0xFFE2E8F0));

  @override
  Widget build(BuildContext context) {
    final rows = [...widget.rows]..sort((a, b) {
      if (a.date == null || b.date == null) return 0;
      return a.date!.compareTo(b.date!);
    });
    final avg = _progAvg(rows, '', widget.variety);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proforma – Factory wise'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to Excel',
            onPressed: () => _exportToExcel(rows, avg),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 4,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text('PROFORMA FOR KAPAS PURCHASE',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _stat('FACTORY', widget.factory),
                      _vDivider(),
                      _stat('VARIETY',
                          widget.variety.isEmpty ? 'N/A' : widget.variety),
                      _vDivider(),
                      _stat('ENTRIES', '${rows.length}'),
                    ],
                  ),
                ),
                const Divider(height: 32),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Scrollbar(
                    controller: _hScroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _hScroll,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            color: const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child: Row(
                                children: _fCols
                                    .map((c) =>
                                    _cell(c, c.label, header: true))
                                    .toList()),
                          ),
                          ...rows.map((r) => Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: Color(0xFFE2E8F0),
                                      width: 0.5)),
                            ),
                            child: Row(
                              children: _fCols
                                  .map((c) => _cell(c, c.cell(r),
                                  bold: c.highlight,
                                  color: c.highlight
                                      ? const Color(0xFF059669)
                                      : null))
                                  .toList(),
                            ),
                          )),
                          Container(
                            color: const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child: Row(
                              children: _fCols
                                  .map((c) => _cell(c, c.cell(avg),
                                  bold: true,
                                  color: c.highlight
                                      ? const Color(0xFF059669)
                                      : null))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Total Seed Value: ₹${_f2(avg.seedValue)}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}