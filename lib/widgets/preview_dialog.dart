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
    String safeString(dynamic value, {String defaultValue = ''}) {
      if (value == null) return defaultValue;
      return value.toString();
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
              'PURCHASE REPORT',
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

          // Company Name
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
                safeString(data?['date']).split('T').first.replaceAll('-', '.'),
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
              const Spacer(),
              const Text('VARIETY:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                safeString(data?['variety'], defaultValue: 'BB MOD'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Data Table
          _buildPurchaseTable(data),
        ],
      ),
    );
  }

  Widget _buildPurchaseTable(Map<String, dynamic>? data) {
    // Safe getter helper
    String safeString(dynamic value, {String defaultValue = '0'}) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    final rows = [
      ['1', "DAY'S ARRIVALS IN QTLS / BALES", 'APMC:', safeString(data?['dayArrivalsApmc'])],
      ['', '', 'OUTSIDE APMC:', safeString(data?['dayArrivalsOutside'])],
      ['2', 'PROG. ARRIVALS IN QTLS / BALES', 'APMC:', safeString(data?['progArrivalsApmc'])],
      ['', '', 'OUTSIDE APMC:', safeString(data?['progArrivalsOutside'])],
      ['3', 'MOISTURE PERCENTAGE (%)', '', safeString(data?['moisture'], defaultValue: '8-20%')],
      ['4', 'MARKET RATE (KAPAS RATE IN QTLS)', 'HIGHEST', safeString(data?['marketRateHighest'])],
      ['', '', 'LOWEST', safeString(data?['marketRateLowest'])],
      ['', '', 'AVERAGE', safeString(data?['marketRateAverage'])],
      ['5', 'MARKET OUT TURN', '', '-'],
      ['6', 'MARKET EXPENSES', '', '-'],
      ['7', 'MARKET SHORTAGE', '', '-'],
      ['8', 'MARKET PADTHA', '', '-'],
      ['9', 'MARKET COTTON SEED RATE (PER QTLS)', 'HIGHEST', safeString(data?['marketSeedRateHighest'])],
      ['', '', 'LOWEST', safeString(data?['marketSeedRateLowest'])],
      ['10', 'CCI PURCHASE IN', 'QTLS', safeString(data?['cciPurchaseQtls'])],
      ['', '', 'BALES', safeString(data?['cciPurchaseBales'])],
      ['', '', 'Kapas Moisture %', safeString(data?['cciKapasMoisture'])],
      ['11', 'MSP VALUE (IN LAKHS)', 'DAY WISE', safeString(data?['mspValueDay'])],
      ['', '', 'PROGRESSIVE', safeString(data?['mspValueProg'])],
      ['12', 'No. OF FARMERS BENEFITTED', 'DAY WISE', safeString(data?['farmersDay'])],
      ['', '', 'PROGRESSIVE', safeString(data?['farmersProgressive'])],
      ['13', 'CCI RATE (KAPAS RATE IN QTLS)', 'HIGHEST', safeString(data?['cciRateHighest'])],
      ['', '', 'LOWEST', safeString(data?['cciRateLowest'])],
      ['', '', 'AVERAGE', safeString(data?['cciRateAverage'])],
      ['14', 'CCI COTTON SEED RATE', '', safeString(data?['cciSeedRate'])],
      ['15', 'CCI OUT TURN', '', safeString(data?['cciOutTurn'])],
      ['16', 'CCI SHORTAGE', '', safeString(data?['cciShortage'])],
      ['17', 'CCI EXPENSES', '', safeString(data?['cciExpenses'])],
      ['18', "PROCESSING CYCLE DAY'S", '', safeString(data?['processingCycle'])],
      ['19', 'CCI PADTHA', '', safeString(data?['cciPadtha'])],
      ['20', 'PROGRESSIVE PURCHASE', 'QTLS', safeString(data?['progPurchaseQtls'])],
      ['', '', 'BALES', safeString(data?['progPurchaseBales'])],
      ['21', 'PROGRESSIVE', 'PADTHA', safeString(data?['progPadtha'])],
      ['', '', 'AVG. RATE', safeString(data?['progAvgRate'])],
      ['22', 'BALES PRESSED DETAILS', 'TODAYS', safeString(data?['balesPressedToday'])],
      ['', '', 'PROGRESSIVE', safeString(data?['balesPressedProg'])],
      ['23', 'TOTAL BALES SHIFTED TO GODOWN', '', safeString(data?['totalBalesShifted'])],
      ['24', 'SAMPLE SENT TO B.O FOR TESTING', '', safeString(data?['sampleSent'], defaultValue: '-')],
      ['25', 'HEAP RESULT SENT TO B.O', '', safeString(data?['heapResult'], defaultValue: '-')],
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows.map((row) {
          final isBold = row[0]?.isNotEmpty ?? false;
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isBold ? const Color(0xFFF8FAFC) : Colors.white,
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
                    row[0] ?? '',
                    style: TextStyle(
                      fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 10,
                      color: isBold ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    row[1] ?? '',
                    style: TextStyle(
                      fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 10,
                      color: isBold ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    row[2] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    row[3] ?? '',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
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
              safeString(data?['date']).split('T').first.replaceAll('-', '.'),
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
}