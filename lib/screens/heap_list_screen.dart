import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/apiservice.dart';
import 'heap_view_screen.dart';

class HeapReportsListScreen extends StatefulWidget {
  const HeapReportsListScreen({super.key});

  @override
  State<HeapReportsListScreen> createState() => _HeapReportsListScreenState();
}

class _HeapReportsListScreenState extends State<HeapReportsListScreen> {
  List<Map<String, dynamic>> _heaps = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String? _error;
  String? _deletingId;

  String? _selectedCentreFilter;
  String? _selectedFactoryFilter;

  List<String> get _availableCentres => {
    for (final h in _heaps)
      if ((h['centre']?.toString() ?? '').isNotEmpty)
        h['centre'].toString()
  }.toList()
    ..sort();

  List<String> get _availableFactories => {
    for (final h in _heaps)
      if ((h['factoryName']?.toString() ?? '').isNotEmpty)
        h['factoryName'].toString()
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

    final response = await ApiService.getHeapEntries();
    if (!mounted) return;

    setState(() {
      if (response.success && response.data != null) {
        _heaps = List<Map<String, dynamic>>.from(
            response.data!['entries'] ?? []);
      } else {
        _heaps = [];
        _error = response.message;
      }
      _isLoading = false;
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _filtered = _heaps.where((h) {
        if (_selectedCentreFilter != null &&
            (h['centre']?.toString().toLowerCase() ?? '') !=
                _selectedCentreFilter!.toLowerCase()) {
          return false;
        }
        if (_selectedFactoryFilter != null &&
            (h['factoryName']?.toString().toLowerCase() ?? '') !=
                _selectedFactoryFilter!.toLowerCase()) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _delete(Map<String, dynamic> h) async {
    final id = h['id']?.toString();
    if (id == null || id.isEmpty) return;

    final label =
        '${h['centre'] ?? '—'} — Heap ${h['heapNo'] ?? '—'} — ${h['variety'] ?? '—'}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade700, size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Heap Report',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete the heap report below. This action cannot be undone.',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child:
            const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingId = id);

    final response = await ApiService.deleteHeapEntry(id);
    if (!mounted) return;

    setState(() => _deletingId = null);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(response.success ? 'Heap deleted' : response.message),
      backgroundColor: response.success ? Colors.green : Colors.red,
    ));

    if (response.success) _load();
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      return DateFormat('dd.MM.yyyy').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heap Reports'),
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
                    decoration: _dec('All Centres'),
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
                    value: _selectedFactoryFilter,
                    isExpanded: true,
                    decoration: _dec('All Factories'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Factories')),
                      ..._availableFactories.map(
                              (f) => DropdownMenuItem(value: f, child: Text(f))),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedFactoryFilter = v);
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
                ? _buildError(_error!)
                : _filtered.isEmpty
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No heap reports yet.\nCreate a heap entry to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final h = _filtered[index];
                final isDeleting =
                    _deletingId == h['id']?.toString();
                final centre =
                (h['centre'] ?? '—').toString();
                final variety =
                (h['variety'] ?? '—').toString();
                final factory =
                (h['factoryName'] ?? '—').toString();
                final heapNo = (h['heapNo'] ?? '—').toString();
                final cropYear =
                (h['cropYear'] ?? '—').toString();
                final fromDate = _fmtDate(h['fromDate']);
                final toDate = _fmtDate(h['toDate']);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFEF3C7),
                      child: Icon(Icons.inventory_2_rounded,
                          color: Color(0xFF0F172A)),
                    ),
                    title: Text(
                      '$centre — Heap $heapNo',
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
                          'Factory: $factory  •  Variety: $variety',
                          style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13),
                        ),
                        Text(
                          'Crop Year: $cropYear',
                          style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13),
                        ),
                        if (fromDate.isNotEmpty &&
                            toDate.isNotEmpty)
                          Text(
                            'Purchase: $fromDate → $toDate',
                            style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isDeleting)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red),
                            tooltip: 'Delete',
                            onPressed: () => _delete(h),
                          ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: isDeleting
                        ? null
                        : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HeapViewScreen(
                            heapData: h,
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

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF1F5F9),
    isDense: true,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
  );

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(msg, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }
}