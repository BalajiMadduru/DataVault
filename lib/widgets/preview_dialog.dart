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
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 650),
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
            const SizedBox(height: 16),

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

  String _safeString(dynamic value, {String defaultValue = '0'}) {
    if (value == null) return defaultValue;
    return value.toString();
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

  // Helper to get value for a specific variety
  String _getValueForVariety(Map<String, dynamic>? data, String targetVariety, String field) {
    if (data == null) return '0';

    // If the current entry's variety matches, return the value
    if (data['variety'] == targetVariety) {
      final value = data[field];
      return value?.toString() ?? '0';
    }

    // For other varieties, return '0' (they don't exist in this entry)
    return '0';
  }

  // Helper to get factory value for a specific variety
  String _getFactoryValueForVariety(Map<String, dynamic>? data, String targetVariety, int factoryIndex, String field) {
    if (data == null) return '0';

    // If the current entry's variety matches, get the factory value
    if (data['variety'] == targetVariety) {
      final factories = data['factories'];
      if (factories is List && factoryIndex < factories.length) {
        final factory = factories[factoryIndex];
        if (factory is Map) {
          return factory[field]?.toString() ?? '0';
        }
      }
      return '0';
    }

    // For other varieties, return '0'
    return '0';
  }

  // ============================================================
  // PURCHASE PREVIEW
  // ============================================================

  Widget _buildPurchasePreview(Map<String, dynamic>? data) {
    final dateStr = _formatDate(data?['date']);
    final centre = _safeString(data?['centre'], defaultValue: 'DEVADURGA');
    final currentVariety = _safeString(data?['variety'], defaultValue: 'BB MOD');

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

          // Header: Purchase Date, Centre (like Excel rows 1-2)
          Row(
            children: [
              const Text('Purchase Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              const Text(' : ', style: TextStyle(fontSize: 11)),
              Text(dateStr, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 30),
              const Text('Centre', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              const Text(' : ', style: TextStyle(fontSize: 11)),
              Text(centre, style: const TextStyle(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),

          // Row 3: Variety Header (like Excel row 3)
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

          // Data Rows (4-16 like Excel)
          _buildRowWithThreeValues(
            "Day's Kapas Purchased from No. of Farmers",
            _getValueForVariety(data, 'BB MOD', 'farmersDay'),
            _getValueForVariety(data, 'BB SPL MOD', 'farmersDay'),
            _getValueForVariety(data, 'MECH', 'farmersDay'),
          ),
          _buildRowWithThreeValues(
            'Arrivals (In Bales)',
            _getValueForVariety(data, 'BB MOD', 'arrivalsBales'),
            _getValueForVariety(data, 'BB SPL MOD', 'arrivalsBales'),
            _getValueForVariety(data, 'MECH', 'arrivalsBales'),
          ),
          _buildRowWithThreeValues(
            'CCI Purchases (In Qtls)',
            _getValueForVariety(data, 'BB MOD', 'cciPurchaseQtls'),
            _getValueForVariety(data, 'BB SPL MOD', 'cciPurchaseQtls'),
            _getValueForVariety(data, 'MECH', 'cciPurchaseQtls'),
          ),
          _buildRowWithThreeValues(
            'CCI Purchases (In Bales)',
            _getValueForVariety(data, 'BB MOD', 'cciPurchaseBales'),
            _getValueForVariety(data, 'BB SPL MOD', 'cciPurchaseBales'),
            _getValueForVariety(data, 'MECH', 'cciPurchaseBales'),
          ),
          _buildRowWithThreeValues(
            'Average Kapas rate (In Rs. per qtl)',
            _getValueForVariety(data, 'BB MOD', 'avgKapasRate'),
            _getValueForVariety(data, 'BB SPL MOD', 'avgKapasRate'),
            _getValueForVariety(data, 'MECH', 'avgKapasRate'),
          ),
          _buildRowWithThreeValues(
            'Budgeted Lint Percentage (%)',
            _getValueForVariety(data, 'BB MOD', 'budgetedLint'),
            _getValueForVariety(data, 'BB SPL MOD', 'budgetedLint'),
            _getValueForVariety(data, 'MECH', 'budgetedLint'),
          ),
          _buildRowWithThreeValues(
            'Budgeted Shortage Percentage (%)',
            _getValueForVariety(data, 'BB MOD', 'budgetedShortage'),
            _getValueForVariety(data, 'BB SPL MOD', 'budgetedShortage'),
            _getValueForVariety(data, 'MECH', 'budgetedShortage'),
          ),
          _buildRowWithThreeValues(
            'Cotton seed rate (In Rs. per qtl)',
            _getValueForVariety(data, 'BB MOD', 'cottonSeedRate'),
            _getValueForVariety(data, 'BB SPL MOD', 'cottonSeedRate'),
            _getValueForVariety(data, 'MECH', 'cottonSeedRate'),
          ),
          _buildRowWithThreeValues(
            "Processing cycle (In day's)",
            _getValueForVariety(data, 'BB MOD', 'processingCycle'),
            _getValueForVariety(data, 'BB SPL MOD', 'processingCycle'),
            _getValueForVariety(data, 'MECH', 'processingCycle'),
          ),
          _buildRowWithThreeValues(
            'Proforma Expenses (In Rs. per Candy)',
            _getValueForVariety(data, 'BB MOD', 'proformaExpenses'),
            _getValueForVariety(data, 'BB SPL MOD', 'proformaExpenses'),
            _getValueForVariety(data, 'MECH', 'proformaExpenses'),
          ),
          _buildRowWithThreeValues(
            'Budgeted Padtha (In Rs. per candy)',
            _getValueForVariety(data, 'BB MOD', 'budgetedPadtha'),
            _getValueForVariety(data, 'BB SPL MOD', 'budgetedPadtha'),
            _getValueForVariety(data, 'MECH', 'budgetedPadtha'),
          ),
          _buildRowWithThreeValues(
            "Day's pressed bales (In Bales)",
            _getValueForVariety(data, 'BB MOD', 'dayPressedBales'),
            _getValueForVariety(data, 'BB SPL MOD', 'dayPressedBales'),
            _getValueForVariety(data, 'MECH', 'dayPressedBales'),
          ),
          const SizedBox(height: 6),

          // Market & CCI Rates (rows 17-20 like Excel)
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
            _getValueForVariety(data, 'BB MOD', 'marketHighestRate'),
            _getValueForVariety(data, 'BB SPL MOD', 'marketHighestRate'),
            _getValueForVariety(data, 'MECH', 'marketHighestRate'),
          ),
          _buildRowWithThreeValues(
            'Market Lowest Rate (In Rs. per qtl)',
            _getValueForVariety(data, 'BB MOD', 'marketLowestRate'),
            _getValueForVariety(data, 'BB SPL MOD', 'marketLowestRate'),
            _getValueForVariety(data, 'MECH', 'marketLowestRate'),
          ),
          _buildRowWithThreeValues(
            'CCI Highest Rate (In Rs. per qtl)',
            _getValueForVariety(data, 'BB MOD', 'cciHighestRate'),
            _getValueForVariety(data, 'BB SPL MOD', 'cciHighestRate'),
            _getValueForVariety(data, 'MECH', 'cciHighestRate'),
          ),
          _buildRowWithThreeValues(
            'CCI Lowest Rate (In Rs. per qtl)',
            _getValueForVariety(data, 'BB MOD', 'cciLowestRate'),
            _getValueForVariety(data, 'BB SPL MOD', 'cciLowestRate'),
            _getValueForVariety(data, 'MECH', 'cciLowestRate'),
          ),
          const SizedBox(height: 6),

          // Progressive Values (rows 21-24 like Excel)
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
            _getValueForVariety(data, 'BB MOD', 'progPressedBales'),
            _getValueForVariety(data, 'BB SPL MOD', 'progPressedBales'),
            _getValueForVariety(data, 'MECH', 'progPressedBales'),
          ),
          _buildRowWithThreeValues(
            'Prog. Purchase (Qtls)',
            _getValueForVariety(data, 'BB MOD', 'progPurchaseQtls'),
            _getValueForVariety(data, 'BB SPL MOD', 'progPurchaseQtls'),
            _getValueForVariety(data, 'MECH', 'progPurchaseQtls'),
          ),
          _buildRowWithThreeValues(
            'Prog. Purchase (Bales)',
            _getValueForVariety(data, 'BB MOD', 'progPurchaseBales'),
            _getValueForVariety(data, 'BB SPL MOD', 'progPurchaseBales'),
            _getValueForVariety(data, 'MECH', 'progPurchaseBales'),
          ),
          _buildRowWithThreeValues(
            'Prog. Kapas Purchased from No. of Farmers',
            _getValueForVariety(data, 'BB MOD', 'progFarmers'),
            _getValueForVariety(data, 'BB SPL MOD', 'progFarmers'),
            _getValueForVariety(data, 'MECH', 'progFarmers'),
          ),
          const SizedBox(height: 6),

          // Factory Details (rows 25+ like Excel)
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
          _buildFactoryTable(data),
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

  Widget _buildFactoryTable(Map<String, dynamic>? data) {
    // Get factories from the current data
    List<Map<String, dynamic>> factories = [];
    final factoriesData = data?['factories'];
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

    final currentVariety = _safeString(data?['variety'], defaultValue: 'BB MOD');

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row (like Excel row 26)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                children: [
                  const SizedBox(width: 30, child: Text('SNO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10))),
                  const SizedBox(width: 150, child: Text('Factory Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10))),
                  const SizedBox(width: 20),
                  _buildTableHeader('BB MOD', currentVariety == 'BB MOD'),
                  const SizedBox(width: 10),
                  _buildTableHeader('BB SPL MOD', currentVariety == 'BB SPL MOD'),
                  const SizedBox(width: 10),
                  _buildTableHeader('MECH', currentVariety == 'MECH'),
                ],
              ),
            ),
            // Data Rows (like Excel rows 27-29)
            ...factories.asMap().entries.map((entry) {
              final index = entry.key;
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
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: Text(
                        factories[index]['factoryName']?.toString() ?? '',
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 20),
                    // BB MOD values
                    _buildFactoryValueCell(data, 'BB MOD', index),
                    const SizedBox(width: 10),
                    // BB SPL MOD values
                    _buildFactoryValueCell(data, 'BB SPL MOD', index),
                    const SizedBox(width: 10),
                    // MECH values
                    _buildFactoryValueCell(data, 'MECH', index),
                  ],
                ),
              );
            }),
            // Total Row (like Excel row 30)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                border: const Border(
                  top: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
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
                  _buildTotalCell(data, 'BB MOD'),
                  const SizedBox(width: 10),
                  _buildTotalCell(data, 'BB SPL MOD'),
                  const SizedBox(width: 10),
                  _buildTotalCell(data, 'MECH'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String title, bool isActive) {
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

  Widget _buildFactoryValueCell(Map<String, dynamic>? data, String targetVariety, int factoryIndex) {
    if (data == null) return _buildEmptyFactoryCell();

    if (data['variety'] == targetVariety) {
      final factories = data['factories'];
      if (factories is List && factoryIndex < factories.length) {
        final factory = factories[factoryIndex];
        if (factory is Map) {
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
      }
    }

    return _buildEmptyFactoryCell();
  }

  Widget _buildEmptyFactoryCell() {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: const Text('', textAlign: TextAlign.center),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 70,
          child: const Text('', textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _buildTotalCell(Map<String, dynamic>? data, String targetVariety) {
    if (data == null || data['variety'] != targetVariety) {
      return Row(
        children: [
          SizedBox(
            width: 70,
            child: const Text('', textAlign: TextAlign.center),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 70,
            child: const Text('', textAlign: TextAlign.center),
          ),
        ],
      );
    }

    final factories = data['factories'];
    if (factories is! List) {
      return _buildEmptyFactoryCell();
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

  // ============================================================
  // SEED PREVIEW
  // ============================================================

  Widget _buildSeedPreview(Map<String, dynamic>? data) {
    final dateStr = _formatDate(data?['date']);
    final centre = _safeString(data?['centre'], defaultValue: 'DEVADURGA');
    final reportNo = _safeString(data?['reportNo'], defaultValue: '1');
    final currentVariety = _safeString(data?['variety'], defaultValue: 'BB MOD');

    List<Map<String, dynamic>> factories = [];
    final factoriesData = data?['seedFactories'] ?? data?['factories'];
    if (factoriesData is List) {
      factories = List<Map<String, dynamic>>.from(factoriesData);
    }

    return SingleChildScrollView(
      child: Column(
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

          // Centre, Date, Report No
          Row(
            children: [
              const Text('CENTRE:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  centre.toUpperCase(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              const Text('DATE:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 16),
              const Text('REPORT NO.:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                reportNo,
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
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 35, child: Text('S.No.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 9))),
                          const SizedBox(width: 150, child: Text('Ginning & pressing factory name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 9))),
                          const SizedBox(width: 20),
                          _buildSeedVarietyHeader('BB MOD', currentVariety == 'BB MOD'),
                          const SizedBox(width: 10),
                          _buildSeedVarietyHeader('BB SPL MOD', currentVariety == 'BB SPL MOD'),
                          const SizedBox(width: 10),
                          _buildSeedVarietyHeader('MECH', currentVariety == 'MECH'),
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
                        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                        child: Row(
                          children: [
                            SizedBox(width: 35, child: Text('${index + 1}', style: const TextStyle(fontSize: 9))),
                            SizedBox(
                              width: 150,
                              child: Text(
                                factory['factoryName']?.toString() ?? '',
                                style: const TextStyle(fontSize: 9),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 20),
                            _buildSeedFactoryCell(data, 'BB MOD', index, factory),
                            const SizedBox(width: 10),
                            _buildSeedFactoryCell(data, 'BB SPL MOD', index, factory),
                            const SizedBox(width: 10),
                            _buildSeedFactoryCell(data, 'MECH', index, factory),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeedVarietyHeader(String title, bool isActive) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            'Prog\nRealisable',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 7,
              color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 55,
          child: Text(
            'Prog\nSold',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 7,
              color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 55,
          child: Text(
            "Day's\nUnsold",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 7,
              color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeedFactoryCell(Map<String, dynamic>? data, String targetVariety, int factoryIndex, Map<String, dynamic> defaultFactory) {
    if (data == null || data['variety'] != targetVariety) {
      return Row(
        children: [
          SizedBox(width: 60, child: const Text('', textAlign: TextAlign.center)),
          const SizedBox(width: 4),
          SizedBox(width: 55, child: const Text('', textAlign: TextAlign.center)),
          const SizedBox(width: 4),
          SizedBox(width: 55, child: const Text('', textAlign: TextAlign.center)),
        ],
      );
    }

    final factories = data['seedFactories'] ?? data['factories'];
    if (factories is! List || factoryIndex >= factories.length) {
      return _buildEmptySeedFactoryCell();
    }

    final factory = factories[factoryIndex];
    if (factory is! Map) {
      return _buildEmptySeedFactoryCell();
    }

    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            factory['progressiveRealisable']?.toString() ?? '0',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 55,
          child: Text(
            factory['progressiveSold']?.toString() ?? '0',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 55,
          child: Text(
            factory['dayUnsold']?.toString() ?? '0',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySeedFactoryCell() {
    return Row(
      children: [
        SizedBox(width: 60, child: const Text('', textAlign: TextAlign.center)),
        const SizedBox(width: 4),
        SizedBox(width: 55, child: const Text('', textAlign: TextAlign.center)),
        const SizedBox(width: 4),
        SizedBox(width: 55, child: const Text('', textAlign: TextAlign.center)),
      ],
    );
  }
}