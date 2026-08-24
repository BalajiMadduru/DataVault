import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/apiservice.dart';

class ProformaViewScreen extends StatefulWidget {
  final String purchaseEntryId;
  final String proformaId;

  const ProformaViewScreen({
    super.key,
    this.purchaseEntryId = '',
    this.proformaId = '',
  });

  @override
  State<ProformaViewScreen> createState() => _ProformaViewScreenState();
}

class _ProformaViewScreenState extends State<ProformaViewScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _proformaData;
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

  Future<void> _loadProforma() async {
    setState(() => _isLoading = true);

    ApiResponse response;

    if (widget.proformaId.isNotEmpty) {
      response = await ApiService.getProformaById(widget.proformaId);
    } else if (widget.purchaseEntryId.isNotEmpty) {
      response = await ApiService.getProformaByPurchaseEntry(widget.purchaseEntryId);
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

      final data = _proformaData!;
      final centre = data['centre'] ?? '';
      final variety = data['variety'] ?? '';
      final entries = data['entries'] as Map<String, dynamic>? ?? {};

      final entryList = entries.entries.toList();
      entryList.sort((a, b) {
        final dateA = DateTime.tryParse(a.value['entryDate']?.toString() ?? '');
        final dateB = DateTime.tryParse(b.value['entryDate']?.toString() ?? '');
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

      // Company Header
      sheet.appendRow(['THE COTTON CORPORATION OF INDIA LTD :: BRANCH OFFICE HUBLI']);
      sheet.appendRow([]);

      // Proforma Title with Centre and Variety
      sheet.appendRow([
        'PROFORMA FOR KAPAS PURCHASE',
        'CENTRE: $centre',
        'VARIETY: $variety'
      ]);
      sheet.appendRow([]);

      // Column Headers
      final headers = [
        'DATE', 'QTY', 'RATE', 'AMOUNT', 'FARMERS', 'MOISTURE',
        'Moi. Value', 'SHORTAGE', 'Shortage value', 'PADATHA',
        'Padtha value', 'out Turn', 'Out Turn value', 'seed',
        'seed value', 'bales'
      ];
      sheet.appendRow(headers);

      // Data Rows for each entry
      for (final entry in entryList) {
        final e = entry.value as Map<String, dynamic>;
        final date = DateTime.tryParse(e['entryDate']?.toString() ?? '');
        sheet.appendRow([
          date != null ? DateFormat('dd/MM/yyyy').format(date) : '',
          e['quantity']?.toString() ?? '0',
          e['rate']?.toString() ?? '0',
          (e['amount'] ?? 0).toStringAsFixed(2),
          e['farmers']?.toString() ?? '0',
          e['moisture']?.toString() ?? '0',
          (e['moistureValue'] ?? 0).toStringAsFixed(2),
          e['shortage']?.toString() ?? '0',
          (e['shortageValue'] ?? 0).toStringAsFixed(2),
          e['padtha']?.toString() ?? '0',
          (e['padthaValue'] ?? 0).toStringAsFixed(2),
          e['outTurn']?.toString() ?? '0',
          (e['outTurnValue'] ?? 0).toStringAsFixed(2),
          (e['seed'] ?? 0).toStringAsFixed(2),
          (e['seedValue'] ?? 0).toStringAsFixed(2),
          e['bales']?.toString() ?? ''
        ]);
      }

      // Add PROG. AVG. row
      sheet.appendRow([]);
      sheet.appendRow([
        'PROG. AVG.',
        data['quantity']?.toString() ?? '0',
        data['rate']?.toStringAsFixed(2) ?? '0',
        (data['amount'] ?? 0).toStringAsFixed(2),
        data['farmers']?.toString() ?? '0',
        data['moisture']?.toStringAsFixed(2) ?? '0',
        (data['moistureValue'] ?? 0).toStringAsFixed(2),
        data['shortage']?.toStringAsFixed(2) ?? '0',
        (data['shortageValue'] ?? 0).toStringAsFixed(2),
        data['padtha']?.toStringAsFixed(2) ?? '0',
        (data['padthaValue'] ?? 0).toStringAsFixed(2),
        data['outTurn']?.toStringAsFixed(2) ?? '0',
        (data['outTurnValue'] ?? 0).toStringAsFixed(2),
        data['seed']?.toStringAsFixed(2) ?? '0',
        (data['seedValue'] ?? 0).toStringAsFixed(2),
        data['bales']?.toString() ?? '0'
      ]);

      // Total Seed Value
      sheet.appendRow([]);
      sheet.appendRow([
        'Total Seed Value',
        '', '', '', '', '', '', '', '', '', '', '', '', '',
        '₹${(data['seedValue'] ?? 0).toStringAsFixed(2)}'
      ]);

      final fileBytes = excel.save();
      if (fileBytes != null) {
        String fileName = 'Proforma_${centre}_${variety}_${DateFormat('ddMMyyyy').format(DateTime.now())}.xlsx';
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
    final centre = data['centre'] ?? '';
    final variety = data['variety'] ?? '';
    final entries = data['entries'] as Map<String, dynamic>? ?? {};

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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
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
                          Container(
                            width: 1,
                            height: 40,
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            color: const Color(0xFFE2E8F0),
                          ),
                          Column(
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
                          Container(
                            width: 1,
                            height: 40,
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            color: const Color(0xFFE2E8F0),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'ENTRIES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${entries.length}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
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
                    child: _buildProformaTable(data),
                  ),
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
              const SizedBox(height: 8),
              Text(
                'Total Entries: ${entries.length}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProformaTable(Map<String, dynamic> data) {
    final entries = data['entries'] as Map<String, dynamic>? ?? {};

    final entryList = entries.entries.toList();
    entryList.sort((a, b) {
      final dateA = DateTime.tryParse(a.value['entryDate']?.toString() ?? '');
      final dateB = DateTime.tryParse(b.value['entryDate']?.toString() ?? '');
      if (dateA == null || dateB == null) return 0;
      return dateA.compareTo(dateB);
    });

    final headers = [
      'DATE', 'QTY', 'RATE', 'AMOUNT', 'FARMERS', 'MOISTURE',
      'Moi. Value', 'SHORTAGE', 'Shortage value', 'PADATHA',
      'Padtha value', 'out Turn', 'Out Turn value', 'seed',
      'seed value', 'bales'
    ];

    final numericFields = ['QTY', 'RATE', 'AMOUNT', 'Moi. Value', 'Shortage value',
      'Padtha value', 'Out Turn value', 'seed', 'seed value', 'bales'];
    final boldFields = ['seed value'];
    final avgFields = ['RATE', 'MOISTURE', 'SHORTAGE', 'PADATHA', 'out Turn', 'seed'];

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
              final isNumeric = numericFields.contains(header);
              return Container(
                width: _columnWidth(header),
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

        // Data Rows
        ...entryList.map((entry) {
          final e = entry.value as Map<String, dynamic>;
          final date = DateTime.tryParse(e['entryDate']?.toString() ?? '');
          final values = [
            date != null ? DateFormat('dd/MM/yyyy').format(date) : '',
            e['quantity']?.toString() ?? '0',
            e['rate']?.toString() ?? '0',
            (e['amount'] ?? 0).toStringAsFixed(2),
            e['farmers']?.toString() ?? '0',
            e['moisture']?.toString() ?? '0',
            (e['moistureValue'] ?? 0).toStringAsFixed(2),
            e['shortage']?.toString() ?? '0',
            (e['shortageValue'] ?? 0).toStringAsFixed(2),
            e['padtha']?.toString() ?? '0',
            (e['padthaValue'] ?? 0).toStringAsFixed(2),
            e['outTurn']?.toString() ?? '0',
            (e['outTurnValue'] ?? 0).toStringAsFixed(2),
            (e['seed'] ?? 0).toStringAsFixed(2),
            (e['seedValue'] ?? 0).toStringAsFixed(2),
            e['bales']?.toString() ?? ''
          ];

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: const Color(0xFFE2E8F0), width: 0.5),
              ),
            ),
            child: Row(
              children: List.generate(values.length, (index) {
                final isNumeric = numericFields.contains(headers[index]);
                final isBold = boldFields.contains(headers[index]);
                return Container(
                  width: _columnWidth(headers[index]),
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
          );
        }).toList(),

        // PROG. AVG. Row
        Container(
          color: const Color(0xFF0F172A),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: _columnWidth('DATE'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: const Text(
                  'PROG. AVG.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                width: _columnWidth('QTY'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  data['quantity']?.toString() ?? '0',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Container(
                width: _columnWidth('RATE'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  data['rate']?.toStringAsFixed(2) ?? '0',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Container(
                width: _columnWidth('AMOUNT'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  (data['amount'] ?? 0).toStringAsFixed(2),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Container(
                width: _columnWidth('FARMERS'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  data['farmers']?.toString() ?? '0',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Container(
                width: _columnWidth('MOISTURE'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  data['moisture']?.toStringAsFixed(2) ?? '0',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Container(
                width: _columnWidth('Moi. Value'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  (data['moistureValue'] ?? 0).toStringAsFixed(2),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Container(
                width: _columnWidth('SHORTAGE'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  data['shortage']?.toStringAsFixed(2) ?? '0',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Container(
                width: _columnWidth('Shortage value'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  (data['shortageValue'] ?? 0).toStringAsFixed(2),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Container(
                width: _columnWidth('PADATHA'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  data['padtha']?.toStringAsFixed(2) ?? '0',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Container(
                width: _columnWidth('Padtha value'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  (data['padthaValue'] ?? 0).toStringAsFixed(2),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Container(
                width: _columnWidth('out Turn'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  data['outTurn']?.toStringAsFixed(2) ?? '0',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Container(
                width: _columnWidth('Out Turn value'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  (data['outTurnValue'] ?? 0).toStringAsFixed(2),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Container(
                width: _columnWidth('seed'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  data['seed']?.toStringAsFixed(2) ?? '0',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Container(
                width: _columnWidth('seed value'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  (data['seedValue'] ?? 0).toStringAsFixed(2),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Color(0xFF4ADE80),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Container(
                width: _columnWidth('bales'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  data['bales']?.toString() ?? '0',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _columnWidth(String header) {
    switch (header) {
      case 'DATE':
        return 90;
      case 'QTY':
      case 'RATE':
      case 'AMOUNT':
        return 80;
      case 'FARMERS':
        return 70;
      case 'MOISTURE':
        return 80;
      case 'Moi. Value':
      case 'Shortage value':
      case 'Padtha value':
      case 'Out Turn value':
        return 85;
      case 'SHORTAGE':
      case 'PADATHA':
      case 'out Turn':
        return 80;
      case 'seed':
        return 60;
      case 'seed value':
        return 80;
      case 'bales':
        return 60;
      default:
        return 60;
    }
  }
}