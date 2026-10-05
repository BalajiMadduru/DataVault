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
  List<Map<String, dynamic>> _proformas = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String? _error;

  String? _selectedCentreFilter;
  String? _selectedVarietyFilter;

  List<String> get _availableCentres => {
    for (final p in _proformas)
      if ((p['centre']?.toString() ?? '').isNotEmpty)
        p['centre'].toString()
  }.toList()
    ..sort();

  List<String> get _availableVarieties => {
    for (final p in _proformas)
      if ((p['variety']?.toString() ?? '').isNotEmpty)
        p['variety'].toString()
  }.toList()
    ..sort();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final response = await ApiService.getProformas();
    if (!mounted) return;
    setState(() {
      if (response.success && response.data != null) {
        _proformas = List<Map<String, dynamic>>.from(
            response.data!['proformas'] ?? []);
      } else {
        _proformas = [];
        _error = response.message;
      }
      _isLoading = false;
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _filtered = _proformas.where((p) {
        if (_selectedCentreFilter != null &&
            (p['centre']?.toString().toLowerCase() ?? '') !=
                _selectedCentreFilter!.toLowerCase()) {
          return false;
        }
        if (_selectedVarietyFilter != null &&
            (p['variety']?.toString().toLowerCase() ?? '') !=
                _selectedVarietyFilter!.toLowerCase()) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final id = p['id']?.toString();
    if (id == null || id.isEmpty) return;
    final label = '${p['centre'] ?? '—'} — ${p['variety'] ?? '—'}';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Proforma'),
        content: Text('Delete the proforma for $label?\n'
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final response = await ApiService.deleteProforma(id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(response.success ? 'Proforma deleted' : response.message),
      backgroundColor: response.success ? Colors.green : Colors.red,
    ));
    if (response.success) _load();
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw.toString());
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return '';
    }
  }

  int _entryCount(Map<String, dynamic> p) {
    final entries = p['entries'];
    if (entries is Map) return entries.length;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proforma – Centre wise'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCentreFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'All Centres',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Centres')),
                      ..._availableCentres.map(
                              (c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedCentreFilter = v);
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedVarietyFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'All Varieties',
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Varieties')),
                      ..._availableVarieties.map(
                              (v) => DropdownMenuItem(value: v, child: Text(v))),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedVarietyFilter = v);
                      _applyFilters();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('❌ $_error',
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : _filtered.isEmpty
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No proforma reports yet.\nCreate a purchase entry to generate one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final p = _filtered[index];
                final centre = (p['centre'] ?? '—').toString();
                final variety = (p['variety'] ?? '—').toString();
                final count = _entryCount(p);
                final dateRangeStart =
                _fmtDate(p['dateRangeStart']);
                final dateRangeEnd = _fmtDate(p['dateRangeEnd']);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2FE),
                      child: Icon(Icons.picture_as_pdf,
                          color: Color(0xFF0F172A)),
                    ),
                    title: Text(
                      '$centre — $variety',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Entries: $count',
                          style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13),
                        ),
                        if (dateRangeStart.isNotEmpty &&
                            dateRangeEnd.isNotEmpty)
                          Text(
                            'Date range: $dateRangeStart → $dateRangeEnd',
                            style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () => _delete(p),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      final id = p['id']?.toString();
                      if (id == null || id.isEmpty) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProformaViewScreen(
                            proformaId: id,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}