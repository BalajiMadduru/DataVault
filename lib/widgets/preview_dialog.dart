import 'package:flutter/material.dart';
import '../enums/report_type.dart';

class PreviewDialog extends StatelessWidget {
  final ReportType type;
  final Map<String, dynamic>? data;

  const PreviewDialog({
    super.key,
    required this.type,
    this.data,
  });

  static const List<String> _varieties = ['BB MOD', 'BB SPL MOD', 'MECH'];

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
                  child: Icon(_icon, color: const Color(0xFF0F172A), size: 24),
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
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Exporting to Excel...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export Excel'),
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
    );
  }

  Widget _buildBody() {
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
  // PURCHASE PREVIEW
  // ============================================================

  Widget _buildPurchasePreview(Map<String, dynamic>? data) {
    final dateStr = _formatDate(data?['date']);
    final centre =
    (data?['centre'] ?? 'DEVADURGA').toString().toUpperCase();
    final cropSeason = (data?['cropSeason'] ?? '2025-26').toString();
    final branchOffice =
    (data?['branchOffice'] ?? 'MAHABUBNAGAR').toString().toUpperCase();

    final rows = <List<String>>[
      ['4', "Day's Kapas Purchased from No. of Farmers / No. of Takpatties",
        _v(data, 'BB MOD', 'farmersDay'), _v(data, 'BB SPL MOD', 'farmersDay'), _v(data, 'MECH', 'farmersDay')],
      ['5', 'Arrivals (In Bales)',
        _v(data, 'BB MOD', 'arrivalsBales'), _v(data, 'BB SPL MOD', 'arrivalsBales'), _v(data, 'MECH', 'arrivalsBales')],
      ['6', 'CCI Purchases (In Qtls)',
        _v(data, 'BB MOD', 'cciPurchaseQtls'), _v(data, 'BB SPL MOD', 'cciPurchaseQtls'), _v(data, 'MECH', 'cciPurchaseQtls')],
      ['7', 'CCI Purchases (In Bales)',
        _v(data, 'BB MOD', 'cciPurchaseBales'), _v(data, 'BB SPL MOD', 'cciPurchaseBales'), _v(data, 'MECH', 'cciPurchaseBales')],
      ['8', 'Avarage Kapas rate (In Rs. per qtl)',
        _v(data, 'BB MOD', 'avgKapasRate'), _v(data, 'BB SPL MOD', 'avgKapasRate'), _v(data, 'MECH', 'avgKapasRate')],
      ['9', 'Moisture (%)',
        _v(data, 'BB MOD', 'moisture'), _v(data, 'BB SPL MOD', 'moisture'), _v(data, 'MECH', 'moisture')],
      ['10', 'Budgeted Lint Percetage (%)',
        _v(data, 'BB MOD', 'budgetedLint'), _v(data, 'BB SPL MOD', 'budgetedLint'), _v(data, 'MECH', 'budgetedLint')],
      ['11', 'Budgeted Shortage Percetage (%)',
        _v(data, 'BB MOD', 'budgetedShortage'), _v(data, 'BB SPL MOD', 'budgetedShortage'), _v(data, 'MECH', 'budgetedShortage')],
      ['12', 'Cotton seed Percetage (%)',
        _v(data, 'BB MOD', 'cottonSeedPct'), _v(data, 'BB SPL MOD', 'cottonSeedPct'), _v(data, 'MECH', 'cottonSeedPct')],
      ['13', 'Cotton seed rate  (In Rs. per qtl)',
        _v(data, 'BB MOD', 'cottonSeedRate'), _v(data, 'BB SPL MOD', 'cottonSeedRate'), _v(data, 'MECH', 'cottonSeedRate')],
      ['14', "Processing cycle (In day's)",
        _v(data, 'BB MOD', 'processingCycle'), _v(data, 'BB SPL MOD', 'processingCycle'), _v(data, 'MECH', 'processingCycle')],
      ['15', 'Proforma Expenses (In Rs. per Candy)',
        _v(data, 'BB MOD', 'proformaExpenses'), _v(data, 'BB SPL MOD', 'proformaExpenses'), _v(data, 'MECH', 'proformaExpenses')],
      ['16', 'Budgeted Padtha (In Rs. per candy)',
        _v(data, 'BB MOD', 'budgetedPadtha'), _v(data, 'BB SPL MOD', 'budgetedPadtha'), _v(data, 'MECH', 'budgetedPadtha')],
      ['17', "Day's pressed bales (In Bales)",
        _v(data, 'BB MOD', 'dayPressedBales'), _v(data, 'BB SPL MOD', 'dayPressedBales'), _v(data, 'MECH', 'dayPressedBales')],
      ['18', 'Market Highest Rate (In Rs. per qtl)',
        _v(data, 'BB MOD', 'marketHighestRate'), _v(data, 'BB SPL MOD', 'marketHighestRate'), _v(data, 'MECH', 'marketHighestRate')],
      ['19', 'Market Lowest Rate (In Rs. per qtl)',
        _v(data, 'BB MOD', 'marketLowestRate'), _v(data, 'BB SPL MOD', 'marketLowestRate'), _v(data, 'MECH', 'marketLowestRate')],
      ['20', 'CCI Highest Rate (In Rs. per qtl)',
        _v(data, 'BB MOD', 'cciHighestRate'), _v(data, 'BB SPL MOD', 'cciHighestRate'), _v(data, 'MECH', 'cciHighestRate')],
      ['21', 'CCI Lowest Rate (In Rs. per qtl)',
        _v(data, 'BB MOD', 'cciLowestRate'), _v(data, 'BB SPL MOD', 'cciLowestRate'), _v(data, 'MECH', 'cciLowestRate')],
      ['22', 'Prog. Pressed Bales',
        _v(data, 'BB MOD', 'progPressedBales'), _v(data, 'BB SPL MOD', 'progPressedBales'), _v(data, 'MECH', 'progPressedBales')],
      ['23', 'Prog. Purchase in qtls',
        _v(data, 'BB MOD', 'progPurchaseQtls'), _v(data, 'BB SPL MOD', 'progPurchaseQtls'), _v(data, 'MECH', 'progPurchaseQtls')],
      ['24', 'Prog. Purchase Bales',
        _v(data, 'BB MOD', 'progPurchaseBales'), _v(data, 'BB SPL MOD', 'progPurchaseBales'), _v(data, 'MECH', 'progPurchaseBales')],
      ['25', 'Prog. Kapas Purchased from No. of Farmers  / Prog. No. of Takpatties',
        _v(data, 'BB MOD', 'progFarmers'), _v(data, 'BB SPL MOD', 'progFarmers'), _v(data, 'MECH', 'progFarmers')],
    ];

    return Container(
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
          _numRow('26', 'Factory wise day purchase details',
              'BB MOD', 'BB SPL MOD', 'MECH', bold: true),
          _factorySubHeader(),
          ..._buildFactoryRows(data),
          _totalRow(data),
        ],
      ),
    );
  }

  // ============================================================
  // FACTORY-WISE SECTION — 2 columns per variety × 3 varieties
  // ============================================================

  /// Returns the factories list for a given variety from the preview data.
  /// The primary variety's factories live under `data['factories']`,
  /// while the other varieties' factories live under
  /// `data['otherVarietiesProgressive'][variety]['factories']`.
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

  /// Build a matrix: factoryName -> variety -> { qtls, bales }
  /// Union over all 3 varieties so every factory appears exactly once,
  /// with a column pair for each variety.
  Map<String, Map<String, Map<String, String>>> _buildFactoryMatrix(
      Map<String, dynamic>? data) {
    final matrix = <String, Map<String, Map<String, String>>>{};

    for (final v in _varieties) {
      final list = _factoriesForVariety(data, v);
      for (final f in list) {
        final name = (f['factoryName'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        matrix.putIfAbsent(name, () => <String, Map<String, String>>{});
        matrix[name]![v] = {
          'qtls': _fq(f['progPurchaseQtls']),
          'bales': _fq(f['progPurchaseBales']),
        };
      }
    }
    return matrix;
  }

  /// Sub-header row: for each of the 3 varieties, two sub-columns
  /// ("Prog. Pur. in qtls" and "Prog. Pur. in Bales").
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
          // 3 varieties × 2 columns each = 6 columns
          for (int i = 0; i < _varieties.length; i++) ...[
            _subCell('Prog. Pur.\nin qtls'),
            _subCell('Prog. Pur.\nin Bales'),
          ],
        ],
      ),
    );
  }

  /// One row per factory (across all varieties), showing qty/bales for
  /// each of the 3 varieties.
  List<Widget> _buildFactoryRows(Map<String, dynamic>? data) {
    final matrix = _buildFactoryMatrix(data);

    if (matrix.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('No factory data available',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
        ),
      ];
    }

    // Sort factory names alphabetically for stable output.
    final names = matrix.keys.toList()..sort();

    return names.asMap().entries.map((e) {
      final i = e.key;
      final name = e.value;
      final row = matrix[name]!;
      return _factoryRow3Variety('${i + 1}', name, row);
    }).toList();
  }

  /// A single factory row with 6 numeric cells (2 per variety).
  Widget _factoryRow3Variety(
      String sno,
      String name,
      Map<String, Map<String, String>> row,
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
          for (final v in _varieties) ...[
            _cell(row[v]?['qtls'] ?? '0'),
            _cell(row[v]?['bales'] ?? '0'),
          ],
        ],
      ),
    );
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
                    color: Color(0xFF64748B),
                  )),
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
                    color: const Color(0xFF334155),
                  )),
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
              color: const Color(0xFF0F172A),
            )),
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
              color: Color(0xFF0F172A),
            )),
      ),
    );
  }

  Widget _totalRow(Map<String, dynamic>? data) {
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
          _cell(_v(data, 'BB MOD', 'progPurchaseQtls'), bold: true),
          _cell(_v(data, 'BB MOD', 'progPurchaseBales'), bold: true),
          _cell(_v(data, 'BB SPL MOD', 'progPurchaseQtls'), bold: true),
          _cell(_v(data, 'BB SPL MOD', 'progPurchaseBales'), bold: true),
          _cell(_v(data, 'MECH', 'progPurchaseQtls'), bold: true),
          _cell(_v(data, 'MECH', 'progPurchaseBales'), bold: true),
        ],
      ),
    );
  }

  // ============================================================
  // SEED PREVIEW
  // ============================================================

  Widget _buildSeedPreview(Map<String, dynamic>? data) {
    final dateStr = _formatDate(data?['date']);
    final centre = (data?['centre'] ?? '').toString();
    final reportNo = (data?['reportNo'] ?? '1').toString();

    List<Map<String, dynamic>> factories = [];
    final src = data?['seedFactories'] ?? data?['factories'];
    if (src is List) {
      factories = List<Map<String, dynamic>>.from(src);
    }

    // --- helpers ---
    double _n(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    String _fmt(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

    // --- derived values (same formulas as SeedFactoryRow) ---
    Map<String, String> computeRow(Map<String, dynamic> f) {
      final realisable = _n(f['realisable']);
      final realised = _n(f['realised']);
      final soldQty = _n(f['soldQty']);
      final progDelivery = _n(f['progDelivery']);

      // Ready_1 = if(Realised < Sold Qty, 0, Realised − Sold Qty)
      final ready1 = realised < soldQty ? 0.0 : realised - soldQty;
      // Kaps_1 = Realisable − Sold Qty − Ready_1
      final kaps1 = realisable - soldQty - ready1;
      // Total_1 = Kaps_1 + Ready_1
      final total1 = kaps1 + ready1;

      // Kaps_2 = if(Realised > Sold Qty, 0, Sold Qty − Realised)
      final kaps2 = realised > soldQty ? 0.0 : soldQty - realised;
      // Ready_2 = Sold Qty − Prog Delivery − Kaps_2
      final ready2 = soldQty - progDelivery - kaps2;
      // Total_2 = Kaps_2 + Ready_2
      final total2 = kaps2 + ready2;

      return {
        'realisable': _fmt(realisable),
        'realised': _fmt(realised),
        'soldQty': _fmt(soldQty),
        'progDelivery': _fmt(progDelivery),
        'kaps1': _fmt(kaps1),
        'ready1': _fmt(ready1),
        'total1': _fmt(total1),
        'kaps2': _fmt(kaps2),
        'ready2': _fmt(ready2),
        'total2': _fmt(total2),
        'marketRateMin': _fmt(_n(f['marketRateMin'])),
        'marketRateMax': _fmt(_n(f['marketRateMax'])),
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title bar
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

        // Header
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

        // Factory table
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
                final c = computeRow(f);
                final variety =
                (f['variety'] ?? '').toString().isEmpty
                    ? '—'
                    : f['variety'].toString();

                return DataRow(cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(Text(f['factoryName']?.toString() ?? '')),
                  DataCell(Text(variety)),
                  // PROG. QTY.
                  DataCell(Text(c['realisable']!)),
                  DataCell(Text(c['realised']!)),
                  DataCell(Text(c['soldQty']!)),
                  DataCell(Text(c['progDelivery']!)),
                  // UNSOLD (Kaps / Ready / Total)
                  DataCell(Text(c['kaps1']!)),
                  DataCell(Text(c['ready1']!)),
                  DataCell(Text(c['total1']!)),
                  // SOLD BUT NOT LIFTED (Kaps / Ready / Total)
                  DataCell(Text(c['kaps2']!)),
                  DataCell(Text(c['ready2']!)),
                  DataCell(Text(c['total2']!)),
                  // Market rate
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
  // WEIGHT LIST PREVIEW
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

    final centre = (data['centre'] ?? '').toString().toUpperCase();
    final reportNo = (data['reportNo'] ?? '').toString();
    final variety = (data['variety'] ?? '').toString();
    final pmNo = (data['pmNo'] ?? '').toString();
    final pmarkNo = (data['pmarkNo'] ?? '').toString();
    final prNo = (data['prNo'] ?? '').toString();
    final lotNo = (data['lotNo'] ?? '').toString();
    final sampleBaleNo = (data['sampleBaleNo'] ?? '').toString();
    final godown = (data['godown'] ?? '').toString();
    final noOfBales = (data['noOfBales'] ?? '').toString();
    final moisture = (data['moisture'] ?? '').toString();
    final pressingFactory = (data['pressingFactory'] ?? '').toString();
    final tareWeight = (data['tareWeight'] ?? '').toString();
    final totalGross = (data['totalGrossWeight'] ?? '').toString();
    final totalNett = (data['totalNettWeight'] ?? '').toString();
    final dateStr = _formatDate(data['date']);

    final bales = <Map<String, dynamic>>[];
    final raw = data['baleEntries'];
    if (raw is List) {
      for (final b in raw) {
        if (b is Map) bales.add(Map<String, dynamic>.from(b));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------- Header block ----------
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF94A3B8)),
            color: const Color(0xFFF8FAFC),
          ),
          child: Column(
            children: [
              const Text('THE COTTON CORPORATION OF INDIA LTD',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              const Text('BRANCH OFFICE :: MAHABUBNAGAR',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155))),
              const SizedBox(height: 2),
              Text('CENTRE :: $centre',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155))),
              const SizedBox(height: 8),
              _wMetaRow('REPORT NO', reportNo, 'DATE OF PRESSING', dateStr),
              _wMetaRow('P.MARK NO', pmarkNo, 'P.R.NO', prNo),
              _wMetaRow('VARIETY', variety, 'SAMPLE BALE NO', sampleBaleNo),
              _wMetaRow('LOT NO', lotNo, 'GODOWN', godown),
              _wMetaRow('NO OF BALES', noOfBales, 'MOISTURE', moisture),
              if (pmNo.isNotEmpty) _wMetaRow('PM NO', pmNo, '', ''),
              if (pressingFactory.isNotEmpty)
                _wMetaRow('PRESSING FACTORY', pressingFactory, '', ''),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---------- Bale grid ----------
        if (bales.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No bale weights entered yet',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF94A3B8)),
            ),
            child: Column(
              children: [
                Container(
                  color: const Color(0xFFF1F5F9),
                  padding:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: const Row(
                    children: [
                      Expanded(child: _PreviewHeaderCell('NO')),
                      Expanded(child: _PreviewHeaderCell('Kgs.')),
                      Expanded(child: _PreviewHeaderCell('NO')),
                      Expanded(child: _PreviewHeaderCell('Kgs.')),
                      Expanded(child: _PreviewHeaderCell('NO')),
                      Expanded(child: _PreviewHeaderCell('Kgs.')),
                      Expanded(child: _PreviewHeaderCell('NO')),
                      Expanded(child: _PreviewHeaderCell('Kgs.')),
                      Expanded(child: _PreviewHeaderCell('NO')),
                      Expanded(child: _PreviewHeaderCell('Kgs.')),
                    ],
                  ),
                ),
                // rows
                ..._buildBaleRows(bales),
                // totals
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    border: Border(
                      top: BorderSide(color: Color(0xFF94A3B8), width: 1.2),
                    ),
                  ),
                  padding:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    children: [
                      for (int c = 0; c < 5; c++) ...[
                        const Expanded(
                          child: _PreviewDataCell('', bold: true),
                        ),
                        Expanded(
                          child: _PreviewDataCell(
                            _columnSum(bales, c),
                            bold: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // ---------- Summary ----------
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _summaryRow('Total Gross Weight', totalGross, false),
              const SizedBox(height: 4),
              _summaryRow('Tare Weight', tareWeight, false),
              const SizedBox(height: 4),
              _summaryRow('Total Nett Weight', totalNett, true),
            ],
          ),
        ),
      ],
    );
  }

  /// Bale rows — 5 columns × N rows, matching the entry dialog layout.
  List<Widget> _buildBaleRows(List<Map<String, dynamic>> bales) {
    const cols = 5;
    final total = bales.length;
    final rows = (total / cols).ceil();
    final widgets = <Widget>[];

    for (int r = 0; r < rows; r++) {
      final cells = <Widget>[];
      for (int c = 0; c < cols; c++) {
        final idx = r + (c * rows);
        if (idx >= total) {
          cells.add(const Expanded(child: _PreviewDataCell('')));
          cells.add(const Expanded(child: _PreviewDataCell('')));
        } else {
          final baleNo = (bales[idx]['baleNo'] ?? (idx + 1)).toString();
          final w = bales[idx]['weight'];
          cells.add(Expanded(child: _PreviewDataCell(baleNo)));
          cells.add(Expanded(child: _PreviewDataCell(_fq(w))));
        }
      }

      widgets.add(Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(children: cells),
      ));
    }
    return widgets;
  }

  /// Sum of bales in column `c` (using the same 5-column layout).
  String _columnSum(List<Map<String, dynamic>> bales, int c) {
    const cols = 5;
    final total = bales.length;
    final rows = (total / cols).ceil();
    double sum = 0;
    for (int r = 0; r < rows; r++) {
      final idx = r + (c * rows);
      if (idx >= total) break;
      final w = bales[idx]['weight'];
      sum += w is num ? w.toDouble() : double.tryParse(w.toString()) ?? 0;
    }
    return _fq(sum);
  }

  Widget _wMetaRow(String l1, String v1, String l2, String v2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text('$l1 : ',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B))),
                Expanded(
                  child: Text(v1,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0F172A))),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text('$l2 : ',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B))),
                Expanded(
                  child: Text(v2,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0F172A))),
                ),
              ],
            ),
          ),
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

// ============================================================
// Small helper widgets used inside the weight-list preview
// ============================================================

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