import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
            icon: const Icon(Icons.print),
            onPressed: _proformaData != null ? () => _printProforma() : null,
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

  void _printProforma() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Print functionality coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildProformaContent() {
    final data = _proformaData!;
    final date = DateTime.parse(data['date']);

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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Centre: ${data['centre']}',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                    Text(
                      'Date: ${DateFormat('dd/MM/yyyy').format(date)}',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              _buildProformaTable(data),
              const SizedBox(height: 20),
              _buildSummaryRow('Total Seed Value', '₹${data['seedValue'].toStringAsFixed(2)}', isBold: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProformaTable(Map<String, dynamic> data) {
    final rows = [
      _buildTableRow('Date', DateFormat('dd/MM/yyyy').format(DateTime.parse(data['date']))),
      _buildTableRow('Quantity (Quintals)', data['quantity'].toString()),
      _buildTableRow('Rate (per Quintal)', '₹${data['rate']}'),
      _buildTableRow('Amount', '₹${data['amount'].toStringAsFixed(2)}'),
      _buildTableRow('Farmers', data['farmers'].toString()),
      _buildTableRow('Moisture %', data['moisture'].toString()),
      _buildTableRow('Moisture Value', data['moistureValue'].toStringAsFixed(2)),
      _buildTableRow('Shortage %', data['shortage'].toString()),
      _buildTableRow('Shortage Value', data['shortageValue'].toStringAsFixed(2)),
      _buildTableRow('Padtha %', data['padtha'].toString()),
      _buildTableRow('Padtha Value', data['padthaValue'].toStringAsFixed(2)),
      _buildTableRow('Out Turn %', data['outTurn'].toString()),
      _buildTableRow('Out Turn Value', data['outTurnValue'].toStringAsFixed(2)),
      _buildTableRow('Seed %', data['seed'].toStringAsFixed(2)),
      _buildTableRow('Seed Value', '₹${data['seedValue'].toStringAsFixed(2)}', isBold: true),
    ];

    return Column(children: rows);
  }

  Widget _buildTableRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }
}