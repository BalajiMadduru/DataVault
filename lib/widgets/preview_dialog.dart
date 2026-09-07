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

  @override
  Widget build(BuildContext context) {
    final isPurchase = type == ReportType.dailyPurchase;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 20),

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: isPurchase
                    ? _buildPurchasePreview(data)
                    : _buildSeedPreview(data),
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

  Widget _buildPurchasePreview(Map<String, dynamic>? data) {
    // Safe getter helper
    String safeString(dynamic value, {String defaultValue = '0'}) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    double safeDouble(dynamic value, {double defaultValue = 0}) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }

    final farmersDay = safeString(data?['farmersDay']);
    final arrivalsBales = safeString(data?['arrivalsBales']);
    final cciPurchaseQtls = safeString(data?['cciPurchaseQtls']);
    final cciPurchaseBales = safeString(data?['cciPurchaseBales']);
    final avgKapasRate = safeString(data?['avgKapasRate']);
    final budgetedLint = safeString(data?['budgetedLint']);
    final budgetedShortage = safeString(data?['budgetedShortage']);
    final cottonSeedRate = safeString(data?['cottonSeedRate']);
    final processingCycle = safeString(data?['processingCycle']);
    final proformaExpenses = safeString(data?['proformaExpenses']);
    final budgetedPadtha = safeString(data?['budgetedPadtha']);
    final dayPressedBales = safeString(data?['dayPressedBales']);
    final marketHighestRate = safeString(data?['marketHighestRate']);
    final marketLowestRate = safeString(data?['marketLowestRate']);
    final cciHighestRate = safeString(data?['cciHighestRate']);
    final cciLowestRate = safeString(data?['cciLowestRate']);
    final progPressedBales = safeString(data?['progPressedBales']);
    final progPurchaseQtls = safeString(data?['progPurchaseQtls']);
    final progPurchaseBales = safeString(data?['progPurchaseBales']);
    final progFarmers = safeString(data?['progFarmers']);

    // Get factories
    List<Map<String, dynamic>> factories = [];
    final factoriesData = data?['factories'];
    if (factoriesData is List) {
      factories = List<Map<String, dynamic>>.from(factoriesData);
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'THE COTTON CORPORATION OF INDIA LTD :: BRANCH OFFICE HUBLI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Title
          Container(
            width: double.infinity,
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

          // Header Info
          _buildInfoRow('Purchase Date', _formatDate(data?['date'])),
          _buildInfoRow('Centre', safeString(data?['centre'], defaultValue: 'DEVADURGA')),
          _buildInfoRow('Variety', safeString(data?['variety'], defaultValue: 'BB MOD')),
          const SizedBox(height: 8),

          // Purchase Details
          _buildDetailSection('Purchase Details'),
          _buildDetailRow("Day's Kapas Purchased from No. of Farmers", farmersDay),
          _buildDetailRow('Arrivals (In Bales)', arrivalsBales),
          _buildDetailRow('CCI Purchases (In Qtls)', cciPurchaseQtls),
          _buildDetailRow('CCI Purchases (In Bales)', cciPurchaseBales),
          _buildDetailRow('Average Kapas rate (In Rs. per qtl)', avgKapasRate),
          _buildDetailRow('Budgeted Lint Percentage (%)', budgetedLint),
          _buildDetailRow('Budgeted Shortage Percentage (%)', budgetedShortage),
          _buildDetailRow('Cotton seed rate (In Rs. per qtl)', cottonSeedRate),
          _buildDetailRow("Processing cycle (In day's)", processingCycle),
          _buildDetailRow('Proforma Expenses (In Rs. per Candy)', proformaExpenses),
          _buildDetailRow('Budgeted Padtha (In Rs. per candy)', budgetedPadtha),
          _buildDetailRow("Day's pressed bales (In Bales)", dayPressedBales),
          const SizedBox(height: 8),

          // Rates Section
          _buildDetailSection('Market & CCI Rates'),
          _buildDetailRow('Market Highest Rate (In Rs. per qtl)', marketHighestRate),
          _buildDetailRow('Market Lowest Rate (In Rs. per qtl)', marketLowestRate),
          _buildDetailRow('CCI Highest Rate (In Rs. per qtl)', cciHighestRate),
          _buildDetailRow('CCI Lowest Rate (In Rs. per qtl)', cciLowestRate),
          const SizedBox(height: 8),

          // Progressive Values
          _buildDetailSection('Progressive Values'),
          _buildDetailRow('Prog. Pressed Bales', progPressedBales),
          _buildDetailRow('Prog. Purchase (Qtls)', progPurchaseQtls),
          _buildDetailRow('Prog. Purchase (Bales)', progPurchaseBales),
          _buildDetailRow('Prog. Kapas Purchased from No. of Farmers', progFarmers),
          const SizedBox(height: 8),

          // Factory Details
          if (factories.isNotEmpty) ...[
            _buildDetailSection('Factory Wise Day Purchase Details'),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2E8F0),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFCBD5E1), width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 30, child: _buildTableHeader('SNO')),
                        Expanded(
                          flex: 2,
                          child: _buildTableHeader('Factory Name'),
                        ),
                        SizedBox(width: 80, child: _buildTableHeader('Prog. Pur. (Qtls)')),
                        SizedBox(width: 80, child: _buildTableHeader('Prog. Pur. (Bales)')),
                      ],
                    ),
                  ),
                  // Data Rows
                  ...factories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final factory = entry.value;
                    return Container(
                      width: double.infinity,
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
                          Expanded(
                            flex: 2,
                            child: Text(
                              factory['factoryName']?.toString() ?? '',
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              factory['progPurchaseQtls']?.toString() ?? '0',
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              factory['progPurchaseBales']?.toString() ?? '0',
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const Text(':', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A),
            ),
          ),
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

  Widget _buildSeedPreview(Map<String, dynamic>? data) {
    // Safe getter helper
    String safeString(dynamic value, {String defaultValue = ''}) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    List<Map<String, dynamic>> factories = [];
    final factoriesData = data?['seedFactories'] ?? data?['factories'];
    if (factoriesData is List) {
      factories = List<Map<String, dynamic>>.from(factoriesData);
    } else if (factoriesData is Map<String, dynamic>) {
      factories = [factoriesData];
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
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

        // Centre & Date
        Row(
          children: [
            const Text('CENTRE:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                safeString(data?['centre'], defaultValue: 'DEVADURGA').toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            const Text('DATE:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              _formatDate(data?['date']),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Report No
        Row(
          children: [
            const Text('REPORT NO.:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              safeString(data?['reportNo'], defaultValue: '1'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
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
        // Seed Factory Table
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Row
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2E8F0),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
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
                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                        border: const Border(
                          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Row(
                        children: [
                          SizedBox(width: 35, child: Text('${index + 1}', style: const TextStyle(fontSize: 10))),
                          SizedBox(
                            width: 160,
                            child: Text(
                              safeString(factory['factoryName']),
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 70, child: Text(safeString(factory['variety']), style: const TextStyle(fontSize: 10))),
                          SizedBox(width: 80, child: Text(safeString(factory['progressiveRealisable'], defaultValue: '0'), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                          SizedBox(width: 70, child: Text(safeString(factory['progressiveSold'], defaultValue: '0'), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                          SizedBox(width: 65, child: Text(safeString(factory['dayUnsold'], defaultValue: '0'), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                          SizedBox(width: 60, child: Text(safeString(factory['kapasForm'], defaultValue: '0'), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                          SizedBox(width: 60, child: Text(safeString(factory['readyForm'], defaultValue: '0'), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                          SizedBox(width: 50, child: Text(
                            safeString(factory['total'], defaultValue:
                            ((safeString(factory['kapasForm'], defaultValue: '0')) + (safeString(factory['readyForm'], defaultValue: '0'))).toString()
                            ),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.right,
                          )),
                          SizedBox(width: 60, child: Text(safeString(factory['baseRate'], defaultValue: '0'), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    );
  }
}