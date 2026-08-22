import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/apiservice.dart';

class ProformaViewScreen extends StatefulWidget {
  final String purchaseEntryId;

  const ProformaViewScreen({super.key, required this.purchaseEntryId});

  @override
  State<ProformaViewScreen> createState() => _ProformaViewScreenState();
}

class _ProformaViewScreenState extends State<ProformaViewScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _proformaData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProforma();
  }

  Future<void> _loadProforma() async {
    setState(() => _isLoading = true);

    final response = await ApiService.getProformaByPurchaseEntry(
      widget.purchaseEntryId,
    );

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
            Text(_error!, style: const TextStyle(color: Color(0xFF64748B))),
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

  Future<void> _exportToExcel() async {
    if (_proformaData == null) return;

    try {
      var excel = excel_lib.Excel.createExcel();
      var sheet = excel['Proforma'];

      // Add empty row
      sheet.appendRow([]);

      // Company Header
      sheet.appendRow([
        'THE COTTON CORPORATION OF INDIA LTD :: BRANCH OFFICE HUBLI',
        '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
      ]);

      sheet.appendRow([]);

      // Proforma Title
      sheet.appendRow([
        'PROFORMA FOR KAPAS PURCHASE',
        '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
      ]);

      sheet.appendRow([]);

      // Centre, Variety and Date
      final data = _proformaData!;
      final date = DateTime.parse(data['date']);
      sheet.appendRow([
        'CENTRE:', data['centre'] ?? '',
        '', '', '',
        'VARIETY:', data['variety'] ?? '',
        '', '', '',
        'DATE:', DateFormat('dd/MM/yyyy').format(date),
        '', '', '', ''
      ]);

      sheet.appendRow([]);

      // Column Headers
      sheet.appendRow([
        'DATE',
        'QTY',
        'RATE',
        'AMOUNT',
        'FARMERS',
        'MOISTURE',
        'Moi. Value',
        'SHORTAGE',
        'Shortage value',
        'PADATHA',
        'Padtha value',
        'out Turn',
        'Out Turn value',
        'seed',
        'seed value',
        'bales',
        'HEAP'
      ]);

      // Data Row
      sheet.appendRow([
        DateFormat('dd/MM/yyyy').format(date),
        data['quantity']?.toString() ?? '0',
        data['rate']?.toString() ?? '0',
        (data['amount'] ?? 0).toStringAsFixed(2),
        data['farmers']?.toString() ?? '0',
        data['moisture']?.toString() ?? '0',
        (data['moistureValue'] ?? 0).toStringAsFixed(2),
        data['shortage']?.toString() ?? '0',
        (data['shortageValue'] ?? 0).toStringAsFixed(2),
        data['padtha']?.toString() ?? '0',
        (data['padthaValue'] ?? 0).toStringAsFixed(2),
        data['outTurn']?.toString() ?? '0',
        (data['outTurnValue'] ?? 0).toStringAsFixed(2),
        (data['seed'] ?? 0).toStringAsFixed(2),
        (data['seedValue'] ?? 0).toStringAsFixed(2),
        data['bales']?.toString() ?? '',
        data['heap']?.toString() ?? ''
      ]);

      // Add total row with seed value highlighted
      sheet.appendRow([]);
      sheet.appendRow([
        'Total Seed Value',
        '', '', '', '', '', '', '', '', '', '', '', '',
        '₹${(data['seedValue'] ?? 0).toStringAsFixed(2)}',
        '', '', ''
      ]);

      final fileBytes = excel.save();
      if (fileBytes != null) {
        String fileName = 'Proforma_${data['centre']}_${DateFormat('ddMMyyyy').format(date)}.xlsx';
        String? savePath;

        if (Platform.isAndroid || Platform.isIOS) {
          final directory = await getExternalStorageDirectory();
          if (directory != null) {
            savePath = '${directory.path}/$fileName';
          }
        } else {
          final directory = await getApplicationDocumentsDirectory();
          savePath = '${directory.path}/$fileName';
        }

        if (savePath != null) {
          final file = File(savePath);
          await file.writeAsBytes(fileBytes);

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

  Widget _buildProformaContent() {
    final data = _proformaData!;
    final date = DateTime.parse(data['date']);
    final centre = data['centre'] ?? '';
    final variety = data['variety'] ?? '';

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
                    Text(
                      'PROFORMA FOR KAPAS PURCHASE',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Centre, Variety and Date in a row
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'CENTRE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  centre.isNotEmpty ? centre : 'N/A',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: const Color(0xFFE2E8F0),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'VARIETY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  variety.isNotEmpty ? variety : 'N/A',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: const Color(0xFFE2E8F0),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'DATE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(date),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              // Proforma Table in Excel-like format
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildProformaTable(data),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Seed Value',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '₹${(data['seedValue'] ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProformaTable(Map<String, dynamic> data) {
    final date = DateTime.parse(data['date']);

    // Table headers matching the screenshot
    final headers = [
      'DATE', 'QTY', 'RATE', 'AMOUNT', 'FARMERS',
      'MOISTURE', 'Moi. Value', 'SHORTAGE', 'Shortage value',
      'PADATHA', 'Padtha value', 'out Turn', 'Out Turn value',
      'seed', 'seed value', 'bales', 'HEAP'
    ];

    final values = [
      DateFormat('dd/MM/yyyy').format(date),
      data['quantity']?.toString() ?? '0',
      data['rate']?.toString() ?? '0',
      (data['amount'] ?? 0).toStringAsFixed(2),
      data['farmers']?.toString() ?? '0',
      data['moisture']?.toString() ?? '0',
      (data['moistureValue'] ?? 0).toStringAsFixed(2),
      data['shortage']?.toString() ?? '0',
      (data['shortageValue'] ?? 0).toStringAsFixed(2),
      data['padtha']?.toString() ?? '0',
      (data['padthaValue'] ?? 0).toStringAsFixed(2),
      data['outTurn']?.toString() ?? '0',
      (data['outTurnValue'] ?? 0).toStringAsFixed(2),
      (data['seed'] ?? 0).toStringAsFixed(2),
      (data['seedValue'] ?? 0).toStringAsFixed(2),
      data['bales']?.toString() ?? '',
      data['heap']?.toString() ?? ''
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Container(
          color: const Color(0xFFF1F5F9),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: headers.map((header) {
              final isNumeric = ['QTY', 'RATE', 'AMOUNT', 'Moi. Value', 'Shortage value', 'Padtha value', 'Out Turn value', 'seed', 'seed value', 'bales', 'HEAP'].contains(header);
              return Container(
                width: header == 'DATE' ? 90 :
                header == 'QTY' || header == 'RATE' || header == 'AMOUNT' ? 80 :
                header == 'FARMERS' ? 70 :
                header == 'MOISTURE' ? 80 :
                header == 'Moi. Value' || header == 'Shortage value' || header == 'Padtha value' || header == 'Out Turn value' ? 85 :
                header == 'SHORTAGE' || header == 'PADATHA' || header == 'out Turn' ? 80 :
                header == 'seed' ? 60 :
                header == 'seed value' ? 80 :
                header == 'bales' ? 60 : 60,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  header,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: isNumeric ? TextAlign.right : TextAlign.center,
                ),
              );
            }).toList(),
          ),
        ),
        // Data Row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: List.generate(values.length, (index) {
              final isNumeric = ['QTY', 'RATE', 'AMOUNT', 'Moi. Value', 'Shortage value', 'Padtha value', 'Out Turn value', 'seed', 'seed value', 'bales', 'HEAP'].contains(headers[index]);
              final isBold = headers[index] == 'seed value';
              return Container(
                width: headers[index] == 'DATE' ? 90 :
                headers[index] == 'QTY' || headers[index] == 'RATE' || headers[index] == 'AMOUNT' ? 80 :
                headers[index] == 'FARMERS' ? 70 :
                headers[index] == 'MOISTURE' ? 80 :
                headers[index] == 'Moi. Value' || headers[index] == 'Shortage value' || headers[index] == 'Padtha value' || headers[index] == 'Out Turn value' ? 85 :
                headers[index] == 'SHORTAGE' || headers[index] == 'PADATHA' || headers[index] == 'out Turn' ? 80 :
                headers[index] == 'seed' ? 60 :
                headers[index] == 'seed value' ? 80 :
                headers[index] == 'bales' ? 60 : 60,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  values[index],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    color: isBold ? const Color(0xFF059669) : const Color(0xFF0F172A),
                  ),
                  textAlign: isNumeric ? TextAlign.right : TextAlign.center,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}