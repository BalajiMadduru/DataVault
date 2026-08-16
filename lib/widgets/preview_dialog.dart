import 'package:flutter/material.dart';
import '../enums/report_type.dart';

class PreviewDialog extends StatelessWidget {
  final ReportType type;

  const PreviewDialog({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.preview_rounded,
                    color: Color(0xFF0F172A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${type.label} - Preview',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
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
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        type == ReportType.dailyPurchase
                            ? Icons.shopping_basket_rounded
                            : Icons.eco_rounded,
                        size: 48,
                        color: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        type == ReportType.dailyPurchase
                            ? 'Purchase Report Preview'
                            : 'Seed Report Preview',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Date: ${DateTime.now().toString().split(' ')[0]}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Total Entries: 1',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text('Total Qtls', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                Text('109.2', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            Column(
                              children: [
                                Text('Bales', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                Text('22', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            Column(
                              children: [
                                Text('Farmers', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                Text('2', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                        content: Text('Generating PDF...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('Export PDF'),
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
}