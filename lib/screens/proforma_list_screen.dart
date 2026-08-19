import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/apiservice.dart';
import 'proforma_view_screen.dart';

class ProformaListScreen extends StatefulWidget {
  const ProformaListScreen({super.key});

  @override
  State<ProformaListScreen> createState() => _ProformaListScreenState();
}

class _ProformaListScreenState extends State<ProformaListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _proformas = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProformas();
  }

  Future<void> _loadProformas() async {
    setState(() => _isLoading = true);

    final response = await ApiService.getProformas();

    if (!mounted) return;

    if (response.success && response.data != null) {
      setState(() {
        _proformas = List<Map<String, dynamic>>.from(
          response.data!['proformas'] as List,
        );
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
        title: const Text('Proforma Reports'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProformas,
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
              onPressed: _loadProformas,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _proformas.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 64, color: Color(0xFF94A3B8)),
            SizedBox(height: 16),
            Text(
              'No Proformas Generated Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
            SizedBox(height: 8),
            Text(
              'Generate a proforma from the Purchase Entry dialog',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _proformas.length,
        itemBuilder: (context, index) {
          final proforma = _proformas[index];
          final date = DateTime.parse(proforma['date']);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.picture_as_pdf,
                  color: Color(0xFF059669),
                ),
              ),
              title: Text(
                'Centre: ${proforma['centre']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Date: ${DateFormat('dd/MM/yyyy').format(date)}',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  Text(
                    'Quantity: ${proforma['quantity']} Quintals',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  Text(
                    'Seed Value: ₹${proforma['seedValue'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProformaViewScreen(
                      purchaseEntryId: proforma['purchaseEntryId'],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}