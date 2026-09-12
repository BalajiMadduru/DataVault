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

  /// Reads a field for a specific variety.
  /// - Own variety → reads top-level field directly.
  /// - Other two   → reads from `otherVarietiesProgressive[<variety>][field]`.
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

  @override
  Widget build(BuildContext context) {
    final isPurchase = type == ReportType.dailyPurchase;

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
                    color: isPurchase
                        ? const Color(0xFFE0F2FE)
                        : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPurchase ? Icons.shopping_basket_rounded : Icons
                        .eco_rounded,
                    color: const Color(0xFF0F172A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${isPurchase ? 'Purchase' : 'Seed'} Report Preview',
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
                  child: isPurchase
                      ? _buildPurchasePreview(data)
                      : _buildSeedPreview(data),
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

// ============================================================
// PURCHASE PREVIEW
// ============================================================

  Widget _buildPurchasePreview(Map<String, dynamic>? data) {
    final dateStr = _formatDate(data?['date']);
    final centre =
    (data?['centre'] ?? 'DEVADURGA').toString().toUpperCase();
    final reportNo = (data?['reportNo'] ?? '1').toString();
    final cropSeason = (data?['cropSeason'] ?? '2025-26').toString();
    final branchOffice =
    (data?['branchOffice'] ?? 'MAHABUBNAGAR').toString().toUpperCase();

    final rows = <List<String>>[
      ['4', "Day's Kapas Purchased from No. of Farmers / No. of Takpatties",
        _v(data, 'BB MOD', 'farmersDay'),
        _v(data, 'BB SPL MOD', 'farmersDay'),
        _v(data, 'MECH', 'farmersDay')],
      ['5', 'Arrivals (In Bales)',
        _v(data, 'BB MOD', 'arrivalsBales'),
        _v(data, 'BB SPL MOD', 'arrivalsBales'),
        _v(data, 'MECH', 'arrivalsBales')],
      ['6', 'CCI Purchases (In Qtls)',
        _v(data, 'BB MOD', 'cciPurchaseQtls'),
        _v(data, 'BB SPL MOD', 'cciPurchaseQtls'),
        _v(data, 'MECH', 'cciPurchaseQtls')],
      ['7', 'CCI Purchases (In Bales)',
        _v(data, 'BB MOD', 'cciPurchaseBales'),
        _v(data, 'BB SPL MOD', 'cciPurchaseBales'),
        _v(data, 'MECH', 'cciPurchaseBales')],
      ['8', 'Avarage Kapas rate (In Rs. per qtl)',
        _v(data, 'BB MOD', 'avgKapasRate'),
        _v(data, 'BB SPL MOD', 'avgKapasRate'),
        _v(data, 'MECH', 'avgKapasRate')],
      ['9', 'Budgeted Lint Percetage (%)',
        _v(data, 'BB MOD', 'budgetedLint'),
        _v(data, 'BB SPL MOD', 'budgetedLint'),
        _v(data, 'MECH', 'budgetedLint')],
      ['10', 'Budgeted Shortage Percetage (%)',
        _v(data, 'BB MOD', 'budgetedShortage'),
        _v(data, 'BB SPL MOD', 'budgetedShortage'),
        _v(data, 'MECH', 'budgetedShortage')],
      ['11', 'Cotton seed Percetage (%)',
        _v(data, 'BB MOD', 'cottonSeedPct'),
        _v(data, 'BB SPL MOD', 'cottonSeedPct'),
        _v(data, 'MECH', 'cottonSeedPct')],
      ['12', 'Cotton seed rate  (In Rs. per qtl)',
        _v(data, 'BB MOD', 'cottonSeedRate'),
        _v(data, 'BB SPL MOD', 'cottonSeedRate'),
        _v(data, 'MECH', 'cottonSeedRate')],
      ['13', "Processing cycle (In day's)",
        _v(data, 'BB MOD', 'processingCycle'),
        _v(data, 'BB SPL MOD', 'processingCycle'),
        _v(data, 'MECH', 'processingCycle')],
      ['14', 'Proforma Expenses (In Rs. per Candy)',
        _v(data, 'BB MOD', 'proformaExpenses'),
        _v(data, 'BB SPL MOD', 'proformaExpenses'),
        _v(data, 'MECH', 'proformaExpenses')],
      ['15', 'Budgeted Padtha (In Rs. per candy)',
        _v(data, 'BB MOD', 'budgetedPadtha'),
        _v(data, 'BB SPL MOD', 'budgetedPadtha'),
        _v(data, 'MECH', 'budgetedPadtha')],
      ['16', "Day's pressed bales (In Bales)",
        _v(data, 'BB MOD', 'dayPressedBales'),
        _v(data, 'BB SPL MOD', 'dayPressedBales'),
        _v(data, 'MECH', 'dayPressedBales')],
      ['17', 'Market Highest Rate (In Rs. per qtl)',
        _v(data, 'BB MOD', 'marketHighestRate'),
        _v(data, 'BB SPL MOD', 'marketHighestRate'),
        _v(data, 'MECH', 'marketHighestRate')],
      ['18', 'Market Lowest Rate (In Rs. per qtl)',
        _v(data, 'BB MOD', 'marketLowestRate'),
        _v(data, 'BB SPL MOD', 'marketLowestRate'),
        _v(data, 'MECH', 'marketLowestRate')],
      ['19', 'CCI Highest Rate (In Rs. per qtl)',
        _v(data, 'BB MOD', 'cciHighestRate'),
        _v(data, 'BB SPL MOD', 'cciHighestRate'),
        _v(data, 'MECH', 'cciHighestRate')],
      ['20', 'CCI Lowest Rate (In Rs. per qtl)',
        _v(data, 'BB MOD', 'cciLowestRate'),
        _v(data, 'BB SPL MOD', 'cciLowestRate'),
        _v(data, 'MECH', 'cciLowestRate')],

// ⭐ Progressive rows — other varieties read from otherVarietiesProgressive
      ['21', 'Prog. Pressed Bales',
        _v(data, 'BB MOD', 'progPressedBales'),
        _v(data, 'BB SPL MOD', 'progPressedBales'),
        _v(data, 'MECH', 'progPressedBales')],
      ['22', 'Prog. Purchase in qtls',
        _v(data, 'BB MOD', 'progPurchaseQtls'),
        _v(data, 'BB SPL MOD', 'progPurchaseQtls'),
        _v(data, 'MECH', 'progPurchaseQtls')],
      ['23', 'Prog. Purchase Bales',
        _v(data, 'BB MOD', 'progPurchaseBales'),
        _v(data, 'BB SPL MOD', 'progPurchaseBales'),
        _v(data, 'MECH', 'progPurchaseBales')],
      [
        '24',
        'Prog. Kapas Purchased from No. of Farmers  / Prog. No. of Takpatties',
        _v(data, 'BB MOD', 'progFarmers'),
        _v(data, 'BB SPL MOD', 'progFarmers'),
        _v(data, 'MECH', 'progFarmers')
      ],
    ];

    List<Map<String, dynamic>> factories = [];
    final src = data?['factories'];
    if (src is List) factories = List<Map<String, dynamic>>.from(src);

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

          _numRow('25', 'Factory wise day purchase details',
              'BB MOD', 'BB SPL MOD', 'MECH', bold: true),
          _factorySubHeader(),

          if (factories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No factory data available',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            )
          else
            ...factories
                .asMap()
                .entries
                .map((e) {
              final i = e.key;
              final f = e.value;
              return _factoryRow(
                '${i + 1}',
                f['factoryName']?.toString() ?? '',
                f['progPurchaseQtls']?.toString() ?? '0',
                f['progPurchaseBales']?.toString() ?? '0',
              );
            }),

          _totalRow(data),
        ],
      ),
    );
  }

  Widget _plainRow(String text, {bool bold = false, String? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          const SizedBox(width: 32),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
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
              child: Text(
                n,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: const Color(0xFF334155),
                ),
              ),
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
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: const Color(0xFF0F172A),
          ),
        ),
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
        ],
      ),
    );
  }

  Widget _subCell(String text) {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  Widget _factoryRow(String sno, String name, String qtls, String bales) {
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
              child: Text(
                sno,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Text(
                name,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          _cell(qtls),
          _cell(bales),
        ],
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
              child: Text(
                'TOTAL',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
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
    final centre = (data?['centre'] ?? 'DEVADURGA').toString();
    final reportNo = (data?['reportNo'] ?? '1').toString();
    final currentVariety = (data?['variety'] ?? 'BB MOD').toString();

    List<Map<String, dynamic>> factories = [];
    final src = data?['seedFactories'] ?? data?['factories'];
    if (src is List) {
      factories = List<Map<String, dynamic>>.from(src);
    }

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
              child: Text(centre.toUpperCase(),
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
                  style:
                  TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
              rows: factories
                  .asMap()
                  .entries
                  .map((e) {
                final i = e.key;
                final f = e.value;
                final total = f['total'] ??
                    ((f['kapasForm'] ?? 0) + (f['readyForm'] ?? 0));
                return DataRow(cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(Text(f['factoryName']?.toString() ?? '')),
                  DataCell(Text(f['variety']?.toString() ?? currentVariety)),
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
}