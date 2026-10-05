import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../enums/report_type.dart';
import '../services/apiservice.dart';
import '../widgets/preview_dialog.dart';
import 'proforma_view_screen.dart';

/// Lists reports for a given type: 'purchase' | 'seed' | 'weightList'.
class ReportsListScreen extends StatefulWidget {
  final String reportType;

  const ReportsListScreen({super.key, required this.reportType});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;
  String? _deletingId;

  String get _title {
    switch (widget.reportType) {
      case 'purchase':
        return 'Purchase Reports';
      case 'seed':
        return 'Seed Reports';
      case 'weightList':
        return 'Weight List Reports';
      default:
        return 'Reports';
    }
  }

  ReportType get _reportTypeEnum {
    switch (widget.reportType) {
      case 'purchase':
        return ReportType.dailyPurchase;
      case 'seed':
        return ReportType.dailySeed;
      case 'weightList':
        return ReportType.weightList;
      default:
        return ReportType.dailyPurchase;
    }
  }

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

    final result = await _fetch();
    if (!mounted) return;

    setState(() {
      _items = result.items;
      _error = result.error;
      _isLoading = false;
    });
  }

  Future<({List<Map<String, dynamic>> items, String? error})> _fetch() async {
    ApiResponse response;
    switch (widget.reportType) {
      case 'purchase':
        response = await ApiService.getPurchaseEntries();
        break;
      case 'seed':
        response = await ApiService.getSeedEntries();
        break;
      case 'weightList':
        response = await ApiService.getWeightListEntries();
        break;
      default:
        return (
        items: <Map<String, dynamic>>[],
        error: '$_title are not connected to the API yet.'
        );
    }

    if (response.success && response.data != null) {
      final list = (response.data!['entries'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return (items: list, error: null);
    }
    return (items: <Map<String, dynamic>>[], error: response.message);
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw.toString();
    }
  }

  // ------------------------------------------------------------
  // OPEN PREVIEW
  // ------------------------------------------------------------

  void _openPreview(Map<String, dynamic> entry) {
    showDialog(
      context: context,
      builder: (_) => PreviewDialog(
        type: _reportTypeEnum,
        data: entry,
      ),
    );
  }

  // ------------------------------------------------------------
  // DELETE
  // ------------------------------------------------------------

  Future<void> _confirmAndDelete(Map<String, dynamic> e) async {
    final id = (e['id'] ?? e['_id'])?.toString();
    if (id == null || id.isEmpty) return;

    final centre = (e['centre'] ?? '—').toString();
    final variety = (e['variety'] ?? '').toString();
    final date = _fmtDate(e['date']);
    final reportNo = (e['reportNo'] ?? '').toString();

    final label = [
      if (centre.isNotEmpty) centre,
      if (variety.isNotEmpty) variety,
      if (reportNo.isNotEmpty) 'Report No: $reportNo',
      if (date.isNotEmpty) date,
    ].join('  •  ');

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
                'Delete Report',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete the report below. '
                  'This action cannot be undone.',
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
            if (widget.reportType == 'purchase') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Any proforma entry linked to this purchase will '
                          'also be removed.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ],
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
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingId = id);

    final ApiResponse response;
    if (widget.reportType == 'weightList') {
      response = await ApiService.deleteWeightListEntry(id);
    } else {
      response = await ApiService.deleteEntry(id);
    }

    if (!mounted) return;

    setState(() => _deletingId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.success
            ? 'Report deleted'
            : 'Delete failed: ${response.message}'),
        backgroundColor: response.success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );

    if (response.success) {
      setState(() {
        _items.removeWhere((it) => (it['id'] ?? it['_id'])?.toString() == id);
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
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
      body: _isLoading
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
              child: Text(_error!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _load, child: const Text('Retry')),
          ],
        ),
      )
          : _items.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No reports found.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final e = _items[index];
          final centre = (e['centre'] ?? '—').toString();
          final variety = (e['variety'] ?? '').toString();
          final date = _fmtDate(e['date']);
          final id = (e['id'] ?? e['_id'])?.toString();
          final reportNo = (e['reportNo'] ?? '').toString();

          final isDeleting = id != null && id == _deletingId;

          final subtitleParts = <String>[
            if (date.isNotEmpty) date,
            if (reportNo.isNotEmpty) 'Report No: $reportNo',
          ];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: widget.reportType == 'weightList'
                    ? const Color(0xFFFEF3C7)
                    : widget.reportType == 'seed'
                    ? const Color(0xFFD1FAE5)
                    : const Color(0xFFE0F2FE),
                child: Icon(
                  widget.reportType == 'weightList'
                      ? Icons.scale_rounded
                      : widget.reportType == 'seed'
                      ? Icons.eco_rounded
                      : Icons.description_outlined,
                  color: const Color(0xFF0F172A),
                ),
              ),
              title: Text(
                variety.isEmpty ? centre : '$centre — $variety',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16),
              ),
              subtitle: subtitleParts.isEmpty
                  ? null
                  : Text(subtitleParts.join('  •  '),
                  style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDeleting)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      tooltip: 'Delete',
                      onPressed: () => _confirmAndDelete(e),
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: isDeleting
                  ? null
                  : () {
                if (widget.reportType == 'purchase' &&
                    id != null &&
                    id.isNotEmpty) {
                  // Purchase → full proforma view (existing flow)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProformaViewScreen(
                        purchaseEntryId: id,
                      ),
                    ),
                  );
                } else {
                  // Seed + Weight List → PreviewDialog
                  _openPreview(e);
                }
              },
            ),
          );
        },
      ),
    );
  }
}